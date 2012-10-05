package FS::part_export::dma_radiusmanager;

use strict;
use vars qw($DEBUG %info %options);
use base 'FS::part_export';
use FS::part_svc;
use FS::svc_acct;
use FS::radius_group;
use Tie::IxHash;
use Digest::MD5 'md5_hex';

use Locale::Country qw(code2country);
use Locale::SubCountry;
use Date::Format 'time2str';

tie %options, 'Tie::IxHash',
  'dbname'    => { label=>'Database name', default=>'radius' },
  'username'  => { label=>'Database username' },
  'password'  => { label=>'Database password' },
  'manager'   => { label=>'Manager name' },
  'template_name'   => { label=>'Template service name' },
  'service_prefix'  => { label=>'Service name prefix' },
  'debug'     => { label=>'Enable debugging', type=>'checkbox' },
;

%info = (
  'svc'       => 'svc_acct',
  'desc'      => 'Export to DMA Radius Manager',
  'options'   => \%options,
  'nodomain'  => 'Y',
  'notes'     => '', #XXX
);

$DEBUG = 0;

sub connect {
  my $self = shift;
  my $datasrc = 'dbi:mysql:host='.$self->machine.
                ':database='.$self->option('dbname');
  DBI->connect(
    $datasrc,
    $self->option('username'),
    $self->option('password'),
    { AutoCommit => 0 }
  ) or die $DBI::errstr;
}

sub export_insert  { my $self = shift; $self->dma_rm_queue('insert', @_) }
sub export_delete  { my $self = shift; $self->dma_rm_queue('delete', @_) }
sub export_replace { my $self = shift; $self->dma_rm_queue('replace', @_) }
sub export_suspend { my $self = shift; $self->dma_rm_queue('suspend', @_) }
sub export_unsuspend { my $self = shift; $self->dma_rm_queue('unsuspend', @_) }

sub dma_rm_queue {
  my ($self, $action, $svc_acct, $old) = @_;

  my $svcnum = $svc_acct->svcnum;

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  my $address = $cust_main->address1;
  $address .= ' '.$cust_main->address2 if $cust_main->address2;
  my $country = code2country($cust_main->country);
  my $lsc = Locale::SubCountry->new($cust_main->country);
  my $state = $lsc->full_name($cust_main->state) if defined($lsc);

  my %params = (
    # for the remote side
    username    => $svc_acct->username,
    password    => md5_hex($svc_acct->_password),
    groupid     => $self->option('groupid'),
    enableuser  => 1,
    firstname   => $cust_main->first,
    lastname    => $cust_main->last,
    company     => $cust_main->company,
    phone       => ($cust_main->daytime || $cust_main->night),
    mobile      => $cust_main->mobile,
    city        => $cust_main->city,
    state       => $state, #full name
    zip         => $cust_main->zip,
    country     => $country, #full name
    gpslat      => $cust_main->latitude,
    gpslong     => $cust_main->longitude,
    comment     => 'svcnum'.$svcnum,
    createdby   => $self->option('manager'),
    owner       => $self->option('manager'),
    email       => $cust_main->invoicing_list_emailonly_scalar,

    # used internally by the export
    exportnum   => $self->exportnum,
    svcnum      => $svcnum,
    action      => $action,
    svcpart     => $svc_acct->cust_svc->svcpart,
    _password   => $svc_acct->_password,
  );
  if ( $action eq 'replace' ) {
    $params{'old_username'} = $old->username;
    $params{'old_password'} = $old->_password;
  }
  my $queue = FS::queue->new({
      'svcnum'  => $svcnum,
      'job'     => "FS::part_export::dma_radiusmanager::dma_rm_action",
  });
  $queue->insert(%params);
}

sub dma_rm_action {
  my %params = @_;
  my $svcnum = delete $params{svcnum};
  my $action = delete $params{action};
  my $svcpart = delete $params{svcpart};
  my $exportnum = delete $params{exportnum};

  my $username = $params{username};
  my $password = delete $params{_password};

  my $self = FS::part_export->by_key($exportnum);
  my $dbh = $self->connect;
  local $DEBUG = 1 if $self->option('debug');

  # export the part_svc if needed, and get its srvid
  my $part_svc = FS::part_svc->by_key($svcpart);
  my $srvid = $self->export_part_svc($part_svc, $dbh); # dies on error
  $params{srvid} = $srvid;

  if ( $action eq 'insert' ) {
    $params{'createdon'} = time2str('%Y-%m-%d', time);
    $params{'expiration'} = time2str('%Y-%m-%d', time);
    warn "rm_users: inserting svcnum$svcnum\n" if $DEBUG;
    my $sth = $dbh->prepare( 'INSERT INTO rm_users ( '.
      join(', ', keys(%params)).
      ') VALUES ('.
      join(', ', ('?') x keys(%params)).
      ')'
    );
    $sth->execute(values(%params)) or die $dbh->errstr;

    # minor false laziness w/ sqlradius_insert
    warn "radcheck: inserting $username\n" if $DEBUG;
    $sth = $dbh->prepare( 'INSERT INTO radcheck (
      username, attribute, op, value
    ) VALUES (?, ?, ?, ?)' );
    $sth->execute(
      $username,
      'Cleartext-Password',
      ':=', # :=(
      $password,
    ) or die $dbh->errstr;

    $sth->execute(
      $username,
      'Simultaneous-Use',
      ':=',
      1, # should this be an option?
    ) or die $dbh->errstr;
    # also, we don't support exporting any other radius attrs...
    # those should go in 'custattr' if we need them
  } elsif ( $action eq 'replace' ) {

    my $old_username = delete $params{old_username};
    my $old_password = delete $params{old_password};
    # svcnum is invariant and on the remote side, so we don't need any 
    # of the old fields to do this
    warn "rm_users: updating svcnum$svcnum\n" if $DEBUG;
    my $sth = $dbh->prepare( 'UPDATE rm_users SET '.
      join(', ', map { "$_ = ?" } keys(%params)).
      ' WHERE comment = ?'
    );
    $sth->execute(values(%params), $params{comment}) or die $dbh->errstr;
    # except for username/password changes
    if ( $old_password ne $password ) {
      warn "radcheck: changing password for $old_username\n" if $DEBUG;
      $sth = $dbh->prepare( 'UPDATE radcheck SET value = ? '.
        'WHERE username = ? and attribute = \'Cleartext-Password\''
      );
      $sth->execute($password, $old_username) or die $dbh->errstr;
    }
    if ( $old_username ne $username ) {
      warn "radcheck: changing username $old_username to $username\n"
        if $DEBUG;
      $sth = $dbh->prepare( 'UPDATE radcheck SET username = ? '.
        'WHERE username = ?'
      );
      $sth->execute($username, $old_username) or die $dbh->errstr;
    }

  } elsif ( $action eq 'suspend' ) {

    # this is sufficient
    warn "rm_users: disabling svcnum#$svcnum\n" if $DEBUG;
    my $sth = $dbh->prepare( 'UPDATE rm_users SET enableuser = 0 '.
      'WHERE comment = ?'
    );
    $sth->execute($params{comment}) or die $dbh->errstr;

  } elsif ( $action eq 'unsuspend' ) {

    warn "rm_users: enabling svcnum#$svcnum\n" if $DEBUG;
    my $sth = $dbh->prepare( 'UPDATE rm_users SET enableuser = 1 '.
      'WHERE comment = ?'
    );
    $sth->execute($params{comment}) or die $dbh->errstr;

  } elsif ( $action eq 'delete' ) {

    warn "rm_users: deleting svcnum#$svcnum\n" if $DEBUG;
    my $sth = $dbh->prepare( 'DELETE FROM rm_users WHERE comment = ?' );
    $sth->execute($params{comment}) or die $dbh->errstr;

    warn "radcheck: deleting $username\n" if $DEBUG;
    $sth = $dbh->prepare( 'DELETE FROM radcheck WHERE username = ?' );
    $sth->execute($username) or die $dbh->errstr;

    # if this were smarter it would also delete the rm_services record
    # if it was no longer in use, but that's not really necessary
  }

  $dbh->commit;
  '';
}

=item export_part_svc PART_SVC DBH

Query Radius Manager for a service definition matching the name of 
PART_SVC (optionally with a prefix defined in the export options).  
If there is one, update it to match the attributes of PART_SVC; if 
not, create one.  Then return its srvid.

=cut

sub export_part_svc {
  my ($self, $part_svc, $dbh) = @_;

  # if $dbh exists, use the existing transaction
  # otherwise create our own and commit when finished
  my $commit = 0;
  if (!$dbh) {
    $dbh = $self->connect;
    $commit = 1;
  }

  my $name = $self->option('service_prefix').$part_svc->svc;

  my %params = (
    'srvname'         => $name,
    'enableservice'   => 1,
    'nextsrvid'       => -1,
    'dailynextsrvid'  => -1,
    # force price-related fields to zero
    'unitprice'       => 0,
    'unitpriceadd'    => 0,
    'unitpricetax'    => 0,
    'unitpriceaddtax' => 0,
  );
  my @fixed_groups;
  # use speed settings from fixed usergroups configured on this part_svc
  if ( my $psc = $part_svc->part_svc_column('usergroup') ) {
    # each part_svc really should only have one fixed group with non-null 
    # speed settings, but go by priority order for consistency
    @fixed_groups = 
      sort { $a->priority <=> $b->priority }
      grep { $_ }
      map { FS::radius_group->by_key($_) }
      split(/\s*,\s*/, $psc->columnvalue);
  } # otherwise there are no fixed groups, so leave speed empty

  foreach (qw(down up)) {
    my $speed = "speed_$_";
    foreach my $group (@fixed_groups) {
      if ( ($group->$speed || 0) > 0 ) {
        $params{$_.'rate'} = $group->$speed;
        last;
      }
    }
  }
  # anything else we need here? poolname, maybe?

  warn "rm_services: looking for '$name'\n" if $DEBUG;
  my $sth = $dbh->prepare( 
    'SELECT srvid FROM rm_services WHERE srvname = ? AND enableservice = 1'
  );
  $sth->execute($name) or die $dbh->errstr;
  if ( $sth->rows > 1 ) {
    die "Multiple services with name '$name' found in Radius Manager.\n";

  } elsif ( $sth->rows == 0 ) {
    # leave this blank to disable creating new service defs
    my $template_name = $self->option('template_name');

    die "Can't create a new service profile--no template service specified.\n"
      unless $template_name;

    warn "rm_services: fetching template '$template_name'\n" if $DEBUG;
    $sth = $dbh->prepare('SELECT * FROM rm_services WHERE srvname = ? LIMIT 1');
    $sth->execute($template_name);
    die "Can't create a new service profile--template service ".
      "'$template_name' not found.\n" unless $sth->rows == 1;
    my $template = $sth->fetchrow_hashref;
    %params = (%$template, %params);

    # get the next available srvid
    $sth = $dbh->prepare('SELECT MAX(srvid) FROM rm_services');
    $sth->execute or die $dbh->errstr;
    my $srvid;
    if ( $sth->rows ) {
      $srvid = $sth->fetchrow_arrayref->[0] + 1;
    }
    $params{'srvid'} = $srvid;

    # create a new one based on the template
    warn "rm_services: inserting '$name' as srvid#$srvid\n" if $DEBUG;
    $sth = $dbh->prepare(
      'INSERT INTO rm_services ('.join(', ', keys %params).
      ') VALUES ('.join(', ', map {'?'} keys %params).')'
    );
    $sth->execute(values(%params)) or die $dbh->errstr;
    # also link it to all the managers allowed on the template service
    warn "rm_services: linking to manager\n" if $DEBUG;
    $sth = $dbh->prepare(
      'INSERT INTO rm_allowedmanagers (srvid, managername) '.
      'SELECT ?, managername FROM rm_allowedmanagers WHERE srvid = ?'
    );
    $sth->execute($srvid, $template->{srvid}) or die $dbh->errstr;
    # and the same for NASes
    warn "rm_services: linking to nas\n" if $DEBUG;
    $sth = $dbh->prepare(
      'INSERT INTO rm_allowednases (srvid, nasid) '.
      'SELECT ?, nasid FROM rm_allowednases WHERE srvid = ?'
    );
    $sth->execute($srvid, $template->{srvid}) or die $dbh->errstr;

    $dbh->commit if $commit;
    return $srvid;

  } else { # $sth->rows == 1, it already exists

    my $row = $sth->fetchrow_arrayref;
    my $srvid = $row->[0];
    warn "rm_services: updating srvid#$srvid\n" if $DEBUG;
    $sth = $dbh->prepare(
      'UPDATE rm_services SET '.join(', ', map {"$_ = ?"} keys %params) .
      ' WHERE srvid = ?'
    );
    $sth->execute(values(%params), $srvid) or die $dbh->errstr;

    $dbh->commit if $commit;
    return $srvid;

  }
}

1;
