package FS::part_export::magicmail;

use strict;

use base qw( FS::part_export );

use Data::Dumper;
use MIME::Base64;

use Net::HTTPS::Any qw( https_get https_post );
use XML::Simple;
use URI::Escape;

use FS::Record qw (qsearch);

use vars qw( $DEBUG );
$DEBUG = 0;

=pod

=head1 NAME

FS::part_export::magicmail

=head1 SYNOPSIS

MagicMail integration for Freeside

=head1 REQUIRES

L<Net::HTTPS::Any>

L<XML::Simple>

L<URI::Escape>

=head1 DESCRIPTION

This export offers basic svc_acct provisioning for MagicMail.  Each customer will
map to an account in MagicMail, and each svc_acct exported will map to a user/mailbox.

This module also provides generic methods for working through the MagicMail API, and can
be used as a base for more complex exports to MagicMail (just be sure to override
the C<%info> hash and the L</Hook Methods>.)

L</Hook Methods> return an error message on failure, and a blank string on success.
All other methods return a positive value (usually a hashref) on success and return
nothing on failure, instead setting the error message in the export object using 
L</Error Methods>.  Use L</error> to retrieve this message.

=cut

use vars qw( %info );

tie my %options, 'Tie::IxHash',
  'client_id'       => { label => 'API Client ID',
                         default => '' },
  'client_password' => { label => 'API Client Password',
                         default => '' },
  'account_prefix'  => { label => 'Account Prefix',
                         default => 'FREESIDE' },
  'package'         => { label => 'Package',
                         default => 'EMAIL' },
  'port'            => { label => 'Port',
                         default => 443 },
  'autopurge'       => { type => 'checkbox',
                         label => 'Auto purge user/account on unprovision' },
  'debug'           => { type => 'checkbox',
                         label => 'Enable debug warnings' },
;

%info = (
  'svc'             => 'svc_acct',
  'desc'            => 'Export service to MagicMail, for svc_acct services',
  'options'         => \%options,
  'notes'           => <<'END',
Add service user and email address to MagicMail<BR>
See <A HREF="http://www.freeside.biz/mediawiki/index.php/Freeside:4:Documentation:MagicMail">documentation</A> for details.
END
);

=head1 Hook Methods

=cut

=head2 _export_insert

Hook that is called when service is initially provisioned.
To avoid confusion, don't use for anything else.

For this export, creates a MagicMail account for this customer
if it doesn't exist, activates account if it is suspended/deleted,
creates a user/mailbox on that account for the provisioning service, 
assigns I<package> (specified by export option) to master user on 
account if it hasn't been, and adds the email address for the 
provisioning service.  On error, attempts to purge any newly 
created account/user and remove any newly set package via L</rollback>.

On success, also runs L</sync_magic_packages> (does not cause fatal
error on failure.)

Override this method when using this module as a base for other exports.

=cut

sub _export_insert {
  my ($self, $svc_acct) = @_;
  $self->error_init;
  my $cust_main = $svc_acct->cust_main;
  my $username = $svc_acct->username;
  my $r = {}; #rollback input

  # create customer account if it doesn't exist
  my $newacct = 0;
  my $account_id = $self->cust_account_id($cust_main);
  my $account = $self->get_account($account_id);
  return $self->error if $self->error;
  unless ($account) {
    $account = $self->add_account($account_id,
      'first_name' => $cust_main->first,
      'last_name'  => $cust_main->last,
      # could also add phone & memo
    );
    return $self->error if $self->error;
    $account_id = $account->{'id'};
    $$r{'purge_account'} = $account_id;
  }

  # activate account if suspended/deleted
  my $oldstatus = $account->{'status'};
  unless ($oldstatus eq 'active') {
    $account = $self->activate_account($account_id);
  }
  return $self->rollback($r) if $self->error;
  $$r{'delete_account'} = $account_id
    if $oldstatus eq 'deleted';
  $$r{'suspend_account'} = $account_id
    if $oldstatus eq 'suspended';

  # check for a master user, assign package if found
  my $package = $self->option('package');
  my $muser = $self->get_master_user($account_id);
  return $self->rollback($r) if $self->error;
  if ($muser) {
    my $musername = $muser->{'id'};
    my $packages = $self->get_packages($musername);
    return $self->rollback($r) if $self->error || !$packages;
    unless ($packages->{$package}) {
      $packages = $self->assign_package($musername,$package);
      return $self->rollback($r) if $self->error || !$packages || !$packages->{$package};
      $$r{'remove_package'} = [$musername,$package];
    }
  }

  # add user
  my ($first,$last) = $svc_acct->finger =~ /(.*)\s(.*)/;
  $first ||= $svc_acct->finger || '';
  $last  ||= '';
  my $user = $self->add_user($account_id,$username,
    'first_name'    => $first,
    'last_name'     => $last,
    'password'      => $svc_acct->_password_encryption eq 'plain'
                       ? $svc_acct->get_cleartext_password
                       : $svc_acct->_password,
    'password_type' => $svc_acct->_password_encryption eq 'plain'
                       ? 'plain'
                       : 'encrypted',
    # could also add memo
  );
  return $self->rollback($r) if $self->error;
  $$r{'purge_user'} = $username;

  # assign package if it hasn't been yet
  unless ($muser) {
    die "Unexpected lack of master user on account, please contact a developer"
      unless $user->{'master_user'} eq 'Y';
    $muser = $user;
    # slight false laziness with above
    my $musername = $muser->{'id'};
    my $packages = $self->get_packages($musername);
    return $self->rollback($r) if $self->error || !$packages;
    unless ($packages->{$package}) {
      $packages = $self->assign_package($musername,$package);
      return $self->rollback($r) if $self->error || !$packages || !$packages->{$package};
      $$r{'remove_package'} = [$musername,$package];
    }
  }

  # add email address
  $self->add_email_address($username,$username.'@'.$svc_acct->domain);
  return $self->rollback($r) if $self->error;

  # double-check packages (only throws warnings, no rollback on fail)
  $self->sync_magic_packages($cust_main, 'include' => $svc_acct);

  return '';
}

=head2 _export_delete

Hook that is called when service is unprovisioned.
To avoid confusion, don't use for anything else.

For this export, deletes the email address and user
associated with the provisioning service.  Only sets
an error if this part fails;  everything else simply
generates warnings.

Also attempts to delete the associated account, if there 
aren't any more users on the account.

If deleted user was master user for account and other 
users exist on the account, attempts to make another user 
the master user.

Runs L</sync_magic_packages>.

If the I<autopurge> export option is set, also purges 
newly deleted users/accounts.

Override this method when using this module as a base for other exports.

=cut

sub _export_delete {
  my ($self, $svc_acct) = @_;
  $self->error_init;
  my $cust_main = $svc_acct->cust_main;
  my $username = $svc_acct->username;

  # check account id
  my $user = $self->get_user($username);
  unless ($user) {
    $self->error("Could not remove user from magicmail, username $username not retrievable");
    $self->error_warn;
    return ''; #non-fatal error, allow svc to be unprovisioned
  }
  my $account_id = $user->{'account'};
  return $self->error("Could not remove user from magicmail, account id does not match")
    unless $account_id eq $self->cust_account_id($cust_main); #fatal, sort out before unprovisioning
  
  # check for master change
  my $newmaster;
  if ($user->{'master_user'}) {
    my $users = $self->get_users($account_id);
    if ($users && (keys %$users > 1)) {
      foreach my $somesvc (
        sort { $a->svcnum <=> $b->svcnum } # cheap way of ordering by provision date
          $self->cust_magic_services($cust_main,'ignore'=>$svc_acct)
      ) {
        next unless $users->{uc($somesvc->username)};
        $newmaster = $somesvc->username;
        last;
      }
      $self->error("Cannot find replacement master user for account $account_id")
        unless $newmaster;
    }
    $self->error_warn; #maybe this should be fatal?
  }

  # do the actual deleting
  $self->delete_user($username);
  return $self->error if $self->error;

  ## no fatal errors after this point

  # transfer master user
  $self->make_master_user($newmaster) if $newmaster;
  $self->error_warn;
  $self->sync_magic_packages($cust_main, 'ignore' => $svc_acct);

  # purge user if configured to do so
  $self->purge_user($username) if $self->option('autopurge');
  $self->error_warn;

  # delete account if there are no more users
  my $users = $self->get_users($account_id);
  $self->error_warn;
  return '' unless $users;
  return '' if keys %$users;
  $self->delete_account($account_id);
  return $self->error_warn if $self->error;

  #purge account if configured to do so
  $self->purge_account($account_id) if $self->option('autopurge');
  return $self->error_warn;
}

=head2 _export_replace

Hook that is called when provisioned service is edited.
To avoid confusion, don't use for anything else.

Updates user info & password.  Cannot be used to change user name.

Override this method when using this module as a base for other exports.

=cut

sub _export_replace {
  my($self, $new, $old) = @_;
  $self->error_init;
  my $username = $new->username;

  return "Cannot change username on a magicmail account"
    unless $username eq $old->username;

  # check account id
  my $user = $self->get_user($username);
  return $self->error("Could not update user, username $username not retrievable")
    unless $user;
  my $account_id = $user->{'account'};
  return $self->error("Could not update user $username, account id does not match")
    unless $account_id eq $self->cust_account_id($new); #fatal, sort out before updating

  # update user
  my ($first,$last) = $new->finger =~ /(.*)\s(.*)/;
  $first ||= $new->finger || '';
  $last  ||= '';
  $user = $self->update_user($account_id,$username,
    'first_name'    => $first,
    'last_name'     => $last,
    'password'      => $new->_password_encryption eq 'plain'
                       ? $new->get_cleartext_password
                       : $new->_password,
    'password_type' => $new->_password_encryption eq 'plain'
                       ? 'plain'
                       : 'encrypted',
    # could also add memo
  );
  return $self->error;
}

=head2 _export_suspend

Hook that is called when service is suspended.
To avoid confusion, don't use for anything else.

=cut

sub _export_suspend {
  my ($self, $svc_acct) = @_;
  $self->error_init;
  my $username = $svc_acct->username;

  # check account id
  my $user = $self->get_user($username);
  return $self->error("Could not update user, username $username not retrievable")
    unless $user;
  my $account_id = $user->{'account'};
  return $self->error("Could not update user $username, account id does not match")
    unless $account_id eq $self->cust_account_id($svc_acct); #fatal, sort out before updating

  #suspend user
  $self->suspend_user($username);
  return $self->error;
}

=head2 _export_unsuspend

Hook that is called when service is unsuspended.
To avoid confusion, don't use for anything else.

=cut

sub _export_unsuspend {
  my ($self, $svc_acct) = @_;
  $self->error_init;
  my $username = $svc_acct->username;

  # check account id
  my $user = $self->get_user($username);
  return $self->error("Could not update user, username $username not retrievable")
    unless $user;
  my $account_id = $user->{'account'};
  return $self->error("Could not update user $username, account id does not match")
    unless $account_id eq $self->cust_account_id($svc_acct); #fatal, sort out before updating

  #suspend user
  $self->activate_user($username);
  return $self->error;
}

=head1 Freeside Methods

These methods are specific to freeside, used to translate 
freeside customers/services/exports
into magicmail accounts/users/packages.

=head2 cust_account_id

Accepts either I<$cust_main> or I<$svc_acct>.
Returns MagicMail account_id for this customer under this export.

=cut

sub cust_account_id {
  my ($self, $in) = @_;
  my $cust_main = ref($in) eq 'FS::cust_main' ? $in : $in->cust_main;
  return $self->option('account_prefix') . $cust_main->custnum;
}

=head2 cust_magic_services

Accepts I<$cust_main> or I<$svc_acct> and the following options:

I<ignore> - I<$svc_acct> to be ignored

I<include> - I<$svc_acct> to be included

Returns a list services owned by the customer
that are provisioned in MagicMail with the same I<account_prefix>
(not necessarily the same export.)

I<include> is not checked for compatability with the current 
export.  It will probably cause errors if you pass a service
that doesn't use the current export.

=cut

sub cust_magic_services {
  my ($self, $in, %opt) = @_;
  my $cust_main = ref($in) eq 'FS::cust_main' ? $in : $in->cust_main;
  my @out = 
    grep {
      $opt{'ignore'} ? ($_->svcnum != $opt{'ignore'}->svcnum) : 1;
    }
    map {
      qsearch('svc_acct', { 'svcnum' => $_->svcnum })
    }
    grep {
      grep {
        ($_->exporttype eq 'magicmail')
          && ($_->option('account_prefix') eq $self->option('account_prefix'))
      }
      map {
        qsearch('part_export',{ 'exportnum' => $_->exportnum })
      }
      qsearch('export_svc',{ 'svcpart' => $_->svcpart }) 
    }
    qsearch({
      'table' => 'cust_svc',
      'addl_from' => 'INNER JOIN cust_pkg ON (cust_svc.pkgnum = cust_pkg.pkgnum)',
      'hashref' => { 'cust_pkg.custnum' => $cust_main->custnum }
    }); #end of @out =
  push(@out,$opt{'include'})
    unless grep { $opt{'include'} ? ($_->svcnum == $opt{'include'}->svcnum) : 1 } @out;
  return @out;
}

=head2 cust_magic_packages

Accepts I<$cust_main> or I<$svc_acct> and the same options as L</cust_magic_services>.

Returns list of MagicMail packages for this customer's L</cust_magic_services>
(ie packages that the master user for this customer should have assigned to it.)

=cut

sub cust_magic_packages {
  my ($self, $in, %opt) = @_;
  my $out = {};
  my @svcs = $self->cust_magic_services($in);
  foreach my $svc ($self->cust_magic_services($in,%opt)) {
    # there really should only be one export per service, but loop just in case
    foreach my $export ( $svc->cust_svc->part_svc->part_export('magicmail') ) {
      $out->{$export->option('package')} = 1;
    }
  }
  return keys %$out;
}

=head2 sync_magic_packages

Accepts I<$cust_main> or I<$svc_acct> and the same options as L</cust_magic_services>.

Assigns or removes packages from the master user of L</cust_account_id> so
that they match L</cust_magic_packages>.  (Will only attempt to remove 
non-matching packages if matching packages are all successfully assigned.)

All errors will be immediately cleared by L</error_warn>.
No meaningful return value.

=cut

sub sync_magic_packages {
  my ($self, $in, %opt) = @_;
  my $cust_main = ref($in) eq 'FS::cust_main' ? $in : $in->cust_main;
  my $account_id = $self->cust_account_id($cust_main);
  my $muser = $self->get_master_user($account_id);
  return $self->error_warn if $self->error;
  return $self->error_warn("Could not find master user for account $account_id")
    unless $muser && $muser->{'id'};
  my $musername = $muser->{'id'};
  my $have = $self->get_packages($musername);
  return $self->error_warn if $self->error;
  my %dont = map { $_ => 1 } keys %$have;
  foreach my $want ($self->cust_magic_packages($cust_main,%opt)) {
    delete $dont{$want};
    $self->assign_package($musername,$want)
      unless $have->{$want};
  }
  return $self->error_warn if $self->error;
  foreach my $dont (keys %dont) {
    $self->remove_package($musername,$dont)
  }
  return $self->error_warn;
}

=head1 Helper Methods

These methods combine account, user and package information
through multiple API requests.

=head2 get_accounts_and_users

Returns results of L</get_accounts> with extra 'users' key for
each account, the value of which is the result of L</get_users>
for that account.

=cut

sub get_accounts_and_users {
  my ($self) = @_;
  my $accounts = $self->get_accounts() or return;
  foreach my $account (keys %$accounts) {
    $accounts->{$account}->{'users'} = $self->get_users($account) or return;
  }
  return $accounts;
}

=head2 get_master_user

Accepts I<$account_id>.  Returns hashref of details on master user
for that account (as would be returned by L</get_user>.)
Returns nothing without setting error if master user is not found.

=cut

sub get_master_user {
  my ($self,$account_id) = @_;
  my $users = $self->get_users($account_id);
  return if $self->error || !$users;
  foreach my $username (keys %$users) {
    if ($users->{$username}->{'master_user'} eq 'Y') {
      $users->{$username}->{'id'} = $username;
      return $users->{$username};
    }
  }
  return;
}

=head2 request

	#send a request to https://machine/api/v2/some/function
	my $result = $export->request('POST','/some/function',%args);

Accepts I<$method>, I<$path> and optional I<%args>.  Sends request
to server and returns server response as a hashref (converted from
XML by L<XML::Simple>.)  I<%args> can include a ForceArray key that 
will be passed to L<XML::Simple/XMLin>;  all other args will be
passed in the reqest.  Do not include 'client_type' in I<%args>,
and do not include '/api/v2' in I<$path>.

Used by other methods to send requests;  unless you're editing
this module, you should probably be using those other methods instead.

=cut

sub request {
  my ($self,$method,$path,%args) = @_;
  local $Data::Dumper::Terse = 1;
  unless (grep(/^$method$/,('GET','POST'))) {
    return if $self->error("Can't request method $method");
  }
  my $get = $method eq 'GET';
  my $forcearray = [];
  if (exists $args{'ForceArray'}) {
    $forcearray = delete $args{'ForceArray'};
  }
  $args{'client_type'} = 'FREESIDE';
  my %request = (
    'host'    => $self->machine,
    'port'    => $self->option('port'),
    'path'    => '/api/v2' . $path,
    'headers' => { 
      'Authorization' => 'Basic ' . MIME::Base64::encode(
                                      $self->option('client_id') 
                                      . ':' 
                                      . $self->option('client_password'),
                                    ''),
    },
  );
  my ( $page, $response, %reply_headers );
  if ($get) {
    my $pathargs = '';
    foreach my $field (keys %args) {
      $pathargs .= $pathargs ? '&' : '?';
      $pathargs .= $field . '=' . uri_escape_utf8($args{$field});
    }
    $request{'path'} .= $pathargs;
    warn "Request = " . Dumper(\%request) if $self->debug;
    ( $page, $response, %reply_headers ) = https_get(%request);
  } else {
    foreach my $field (keys %args) {
      $request{'content'} .= '&' if $request{'content'};
      $request{'content'} .= $field . '=' . uri_escape_utf8($args{$field});
    }
    warn "Request = " . Dumper(\%request) if $self->debug;
    ( $page, $response, %reply_headers ) = https_post(%request);
  }
  unless ($response =~ /^(200|400|500)/) {
    return if $self->error("Bad Response: $response");
  }
  warn "Response = " . Dumper($page) if $self->debug;
  my $result = $page ? XMLin($page, ForceArray => $forcearray) : {};
  warn "Result = " . Dumper($result) if $self->debug;
  return $result;
}

=head1 Account Methods

Make individual account-related API requests.

=head2 add_account

Accepts I<$account_id> and the following options:

I<first_name>

I<last_name>

I<phone>

I<memo>

Returns a hashref containing the created account details.

=cut

sub add_account {
  my ($self,$id,%opt) = @_;
  warn "CREATING ACCOUNT $id\n" if $self->debug;
  my %args;
  foreach my $field ( qw( first_name last_name phone memo ) ) {
    $args{$field} = $opt{$field} if $opt{$field};
  }
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), %args );
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 get_account

Accepts I<$account_id>.
Returns a hashref containing account details.  
Returns nothing without setting error if account is not found.

=cut

sub get_account {
  my ($self,$id) = @_;
  warn "GETTING ACCOUNT $id\n" if $self->debug;
  my $result = $self->request('GET','/account/'.uri_escape_utf8($id));
  if ($result->{'error'}) {
    return if $result->{'error'}->{'code'} eq 'account.error.not_found';
  }
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 get_accounts

No input.  Returns a hashref, keys are account_id, values
are hashrefs of account details.

=cut

sub get_accounts {
  my ($self) = @_;
  warn "GETTING ALL ACCOUNTS\n" if $self->debug;
  my $result = $self->request('GET','/account','ForceArray' => ['account']);
  return if $self->check_for_error($result);
  return $result->{'accounts'}->{'account'} || {};
}

=head2 update_account

Accepts I<$account_id> and the same options as L</add_account>.
Updates an existing account.
Returns a hashref containing the updated account details.

=cut

sub update_account {
  my ($self,$id,%opt) = @_;
  warn "UPDATING ACCOUNT $id\n" if $self->debug;
  my %args;
  foreach my $field ( qw( first_name last_name phone memo ) ) {
    $args{$field} = $opt{$field} if $opt{$field};
  }
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), %args, action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 suspend_account

Accepts I<$account_id>.  Sets account status to suspended.
Returns a hashref containing the updated account details.

=cut

sub suspend_account {
  my ($self,$id) = @_;
  warn "SUSPENDING ACCOUNT $id\n" if $self->debug;
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), status => 'suspended', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 activate_account

Accepts I<$account_id>.  Sets account status to active.
Returns a hashref containing the updated account details.

=cut

sub activate_account {
  my ($self,$id) = @_;
  warn "ACTIVATING ACCOUNT $id\n" if $self->debug;
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), status => 'active', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 delete_account

Accepts I<$account_id>.  Sets account status to deleted.
Returns a hashref containing the updated account details.

=cut

sub delete_account {
  my ($self,$id) = @_;
  warn "DELETING ACCOUNT $id\n" if $self->debug;
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), status => 'deleted', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'account'};
}

=head2 purge_account

Accepts account I<$id> and the following options:

I<force> - if true, purges account even if it wasn't first deleted

Purges account from system.
No meaningful return value.

=cut

sub purge_account {
  my ($self,$id,%opt) = @_;
  my %args;
  $args{'force'} = 'true' if $opt{'force'};
  warn "PURGING ACCOUNT $id\n" if $self->debug;
  my $result = $self->request('POST', '/account/'.uri_escape_utf8($id), %args, action => 'purge' );
  $self->check_for_error($result);
  return;
}

=head1 User Methods

Make individual user-related API requests.

=head2 add_user

Accepts I<$account_id>, I<$username> and the following options:

I<first_name>

I<last_name>

I<memo>

I<password>

I<password_type> - plain or encrypted

Returns a hashref containing the created user details.

=cut

sub add_user {
  my ($self,$account_id,$username,%opt) = @_;
  warn "CREATING USER $username FOR ACCOUNT $account_id\n" if $self->debug;
  my %args;
  foreach my $field ( qw( first_name last_name memo password password_type ) ) {
    $args{$field} = $opt{$field} if $opt{$field};
  }
  $args{'account'} = $account_id;
  unless ($account_id) {
    return if $self->error("Account ID required");
  }
  if ($args{'password_type'} && !grep(/$args{'password_type'}/,('plain','encrypted'))) {
    return if $self->error("Illegal password_type $args{'password_type'}");
  }
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), %args );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 get_user

Accepts I<$username>.
Returns a hashref containing user details.  
Returns nothing without setting error if user is not found.

=cut

sub get_user {
  my ($self,$username) = @_;
  warn "GETTING USER $username\n" if $self->debug;
  my $result = $self->request('GET','/user/'.uri_escape_utf8($username));
  if ($result->{'error'}) {
    return if $result->{'error'}->{'code'} eq 'account.error.not_found';
  }
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 get_users

Accepts I<$account_id>.  Returns a hashref, keys are username, values
are hashrefs of user details.

=cut

sub get_users {
  my ($self,$account_id) = @_;
  warn "GETTING ALL USERS FOR ACCOUNT $account_id\n" if $self->debug;
  my $result = $self->request('GET','/user','ForceArray' => ['user'],'account' => $account_id);
  return if $self->check_for_error($result);
  return $result->{'users'}->{'user'} || {};
}

=head2 update_user

Accepts I<$account_id>, I<$username> and the same options as L</add_user>.
Updates an existing user.
Returns a hashref containing the updated user details.

=cut

sub update_user {
  my ($self,$account_id,$username,%opt) = @_;
  warn "UPDATING USER $username\n" if $self->debug;
  my %args;
  foreach my $field ( qw( first_name last_name memo password password_type ) ) {
    $args{$field} = $opt{$field} if $opt{$field};
  }
  if ($args{'password_type'} && !grep(/$args{'password_type'}/,('plain','encrypted'))) {
    return if $self->error("Illegal password_type $args{'password_type'}");
  }
  $args{'account'} = $account_id;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), %args, action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 make_master_user

Accepts I<$username>.  Sets user to be master user for account.
Returns a hashref containing the updated user details.

Caution: does not unmake existing master user.

=cut

sub make_master_user {
  my ($self,$username) = @_;
  warn "MAKING MASTER USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username),
    master_user => 'Y',
    action => 'update'
  );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 suspend_user

Accepts I<$username>.  Sets user status to suspended.
Returns a hashref containing the updated user details.

=cut

sub suspend_user {
  my ($self,$username) = @_;
  warn "SUSPENDING USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), status => 'suspended', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 activate_user

Accepts I<$username>.  Sets user status to active.
Returns a hashref containing the updated user details.

=cut

sub activate_user {
  my ($self,$username) = @_;
  warn "ACTIVATING USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), status => 'active', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 delete_user

Accepts I<$username>.  Sets user status to deleted.
Returns a hashref containing the updated user details.

=cut

sub delete_user {
  my ($self,$username) = @_;
  warn "DELETING USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), status => 'deleted', action => 'update' );
  return if $self->check_for_error($result);
  return $result->{'user'};
}

=head2 purge_user

Accepts I<$username> and the following options:

I<force> - if true, purges user even if it wasn't first deleted

Purges user from system.
No meaningful return value.

=cut

sub purge_user {
  my ($self,$username,%opt) = @_;
  my %args;
  $args{'force'} = 'true' if $opt{'force'};
  warn "PURGING USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user/'.uri_escape_utf8($username), %args, action => 'purge' );
  $self->check_for_error($result);
  return;
}

=head1 Package Methods

Make individual package-related API requests.

=head2 assign_package

Accepts I<$username> and I<$package>.  Assigns package to user.
Returns a hashref of packages assigned to this user, keys are package names
and values are hashrefs of details about those packages.  
Returns undef if none are found.

=cut

sub assign_package {
  my ($self,$username,$package) = @_;
  warn "ASSIGNING PACKAGE $package TO USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user_package/'.uri_escape_utf8($username), 
    'ForceArray' => ['package'], 
    'package' => $package,
  );
  return if $self->check_for_error($result);
  return $result->{'packages'}->{'package'};
}

=head2 get_packages

Accepts I<$username>.
Returns a hashref of packages assigned to this user, keys are package names
and values are hashrefs of details about those packages.

=cut

sub get_packages {
  my ($self,$username) = @_;
  warn "GETTING PACKAGES ASSIGNED TO USER $username\n" if $self->debug;
  my $result = $self->request('GET', '/user_package/'.uri_escape_utf8($username), 
    'ForceArray' => ['package'], 
  );
  return if $self->check_for_error($result);
  return $result->{'packages'}->{'package'} || {};
}

=head2 remove_package

Accepts I<$username> and I<$package>.  Removes package from user.
No meaningful return value.

=cut

sub remove_package {
  my ($self,$username,$package) = @_;
  warn "REMOVING PACKAGE $package FROM USER $username\n" if $self->debug;
  my $result = $self->request('POST', '/user_package/'.uri_escape_utf8($username),
    'package' => $package,
	'action' => 'purge'
  );
  $self->check_for_error($result);
  return;
}

=head1 Domain Methods

Make individual account-related API requests.

=cut

### DOMAIN METHODS HAVEN'T BEEN THOROUGLY TESTED, AREN'T CURRENTLY USED ###

=head2 add_domain

Accepts I<$account_id> and I<$domain>.  Creates domain for that account.

=cut

sub add_domain {
  my ($self,$account_id,$domain) = @_;
  warn "CREATING DOMAIN $domain FOR ACCOUNT $account_id\n" if $self->debug;
  my $result = $self->request('POST','/domain/'.uri_escape_utf8($domain), 'account' => $account_id);
  return if $self->check_for_error($result);
  return $result->{'domain'};
}

=head2 get_domain

Accepts I<$domain>.  Returns hasref of domain info if it exists,
or empty if it doesn't exist or permission denied.
Returns nothing without setting error if domain is not found.

=cut

sub get_domain {
  my ($self, $domain) = @_;
  warn "GETTING DOMAIN $domain\n" if $self->debug;
  my $result = $self->request('GET','/domain/'.uri_escape_utf8($domain));
  if ($result->{'error'}) {
    #unfortunately, no difference between 'does not exist' and true 'permission denied'
    return if $result->{'error'}->{'code'} eq 'error.permission_denied';
  }
  return if $self->check_for_error($result);
  return $result->{'domain'};
}

=head2 get_domains

Accepts I<$account_id>.  Returns hasref of domains for that account,
keys are domains, values are hashrefs of info about each domain.

=cut

sub get_domains {
  my ($self, $account_id) = @_;
  warn "GETTING DOMAINS FOR ACCOUNT $account_id\n" if $self->debug;
  my $result = $self->request('GET','/domain',
    'ForceArray' => ['domain'], 
    'account' => $account_id
  );
  return if $self->check_for_error($result);
  return $result->{'domains'}->{'domain'} || {};
}

=head2 remove_domain

Accepts I<$domain>.  Removes domain.
No meaningful return value.

=cut

sub remove_domain {
  my ($self,$domain) = @_;
  warn "REMOVING DOMAIN $domain\n" if $self->debug;
  my $result = $self->request('POST', '/domain/'.uri_escape_utf8($domain), action => 'purge');
  $self->check_for_error($result);
  return;
}

=head1 Email Address Methods

Make individual emailaddress-related API requests.

=head2 add_email_address

Accepts I<$username> and I<$address>.  Adds address for that user.
Returns hashref of details for new address.

=cut

sub add_email_address {
  my ($self, $username, $address) = @_;
  warn "ADDING ADDRESS $address FOR USER $username\n" if $self->debug;
  my $result = $self->request('POST','/emailaddress/'.uri_escape_utf8($address),
    'user' => $username
  );
  return if $self->check_for_error($result);
  return $result->{'emailaddress'};
}

=head2 get_email_address

Accepts I<$address>.  Returns hasref of address info if it exists,
or empty if it doesn't exist or permission denied.
Returns nothing without setting error if address is not found.

=cut

sub get_email_address {
  my ($self, $address) = @_;
  warn "GETTING ADDRESS $address\n" if $self->debug;
  my $result = $self->request('GET','/emailaddress/'.uri_escape_utf8($address));
  if ($result->{'error'}) {
    #unfortunately, no difference between 'does not exist' and true 'permission denied'
    return if $result->{'error'}->{'code'} eq 'error.permission_denied';
  }
  return if $self->check_for_error($result);
  return $result->{'emailaddress'};
}

=head2 get_email_addresses

Accepts I<$username>.  Returns hasref of email addresses for that account,
keys are domains, values are hashrefs of info about each domain.

=cut

sub get_email_addresses {
  my ($self, $username) = @_;
  warn "GETTING ADDRESSES FOR USER $username\n" if $self->debug;
  my $result = $self->request('GET','/emailaddress',
    'ForceArray' => ['emailaddress'], 
    'user' => $username,
  );
  return if $self->check_for_error($result);
  return $result->{'emailaddresses'}->{'emailaddress'} || {};
}

=head2 remove_email_address

Accepts I<$address>.  Removes address.
No meaningful return value.

=cut

sub remove_email_address {
  my ($self,$address) = @_;
  warn "REMOVING ADDRESS $address\n" if $self->debug;
  my $result = $self->request('POST', '/emailaddress/'.uri_escape_utf8($address), action => 'purge');
  $self->check_for_error($result);
  return;
}

=head1 Error Methods

Used to track errors during a request, for precision control over when
and how those errors are returned.

=head2 error

Accepts optional I<$message>, which will be appended to the internal error message on this
object if defined (use L</init_error> to clear the message.)  Returns current contents of 
internal error message on this object.

=cut

sub error {
  my ($self,$message) = @_;
  if (defined($message)) {
    $self->{'_error'} .= "\n" if $self->{'_error'};
    $self->{'_error'} .= $message;
  }
  return $self->{'_error'};
}

=head2 check_for_error

Accepts I<$result> returned by L</request>.  Sets error if I<$result>
does not exist or contains an error message.  Returns L</error>.

=cut

sub check_for_error {
  my ($self,$result) = @_;
  return $self->error("Unknown error, no result found")
    unless $result;
  return $self->error($result->{'error'}->{'code'} . ': ' . $result->{'error'}->{'message'})
    if $result->{'error'};
  return $self->error;
}

=head2 error_init

Resets error message in object to blank string.
Should only be used at the start of L</Hook Methods>.
No meaningful return value.

=cut

sub error_init {
  my ($self) = @_;
  $self->{'_error'} = '';
  return;
}

=head2 error_warn

Accepts optional I<$message>, which will be appended to the internal error message on this
object if defined.

Outputs L</error> (if there is one) using warn, then runs L</error_init>.
Returns blank string.

=cut

sub error_warn {
  my $self = shift;
  my $message = shift;
  $self->error($message) if defined($message);
  warn $self->error if $self->error;
  $self->error_init;
  return '';
}

=head2 debug

Returns true if debug is set, either as an export option or in the module code.

=cut

sub debug {
  my $self = shift;
  return $DEBUG || $self->option('debug');
}

=head2 rollback

Accepts hashref with the following fields, use for undoing recent changes:

I<remove_package> - arrayref of username and package to remove

I<purge_user> - username to be forcefully purged

I<suspend_account> - account_id to be suspended

I<delete_account> - account_id to be deleted

I<purge_account> - account_id to be forcefully purged

Indicated actions will be performed in the order listed above.
Sets generic error message if no message is found, and returns L</error>.

=cut

sub rollback {
  my ($self,$r) = @_;
  $self->error('Unknown error') unless $self->error;
  $self->remove_package(@{$$r{'remove_package'}}) if $$r{'remove_package'};
  $self->purge_user($$r{'purge_user'}, 'force' => 1) if $$r{'purge_user'};
  $self->suspend_account($$r{'suspend_account'}) if $$r{'suspend_account'};
  $self->delete_account($$r{'delete_account'}) if $$r{'delete_account'};
  $self->purge_account($$r{'purge_account'}, 'force' => 1) if $$r{'purge_account'};
  return $self->error;
}

=head1 SEE ALSO

L<FS::part_export>

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Freeside Internet Services      

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License 
as published by the Free Software Foundation.

=cut

1;


