package FS::access_user;

use strict;
use base qw( FS::m2m_Common FS::option_Common ); 
use vars qw( $DEBUG $me $conf $htpasswd_file );
use FS::UID;
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh );
use FS::access_user_pref;
use FS::access_usergroup;
use FS::agent;
use FS::cust_main;

$DEBUG = 0;
$me = '[FS::access_user]';

#kludge htpasswd for now (i hope this bootstraps okay)
FS::UID->install_callback( sub {
  $conf = new FS::Conf;
  $htpasswd_file = $conf->base_dir. '/htpasswd';
} );

=head1 NAME

FS::access_user - Object methods for access_user records

=head1 SYNOPSIS

  use FS::access_user;

  $record = new FS::access_user \%hash;
  $record = new FS::access_user { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_user object represents an internal access user.  FS::access_user
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item usernum - primary key

=item username - 

=item _password - 

=item last -

=item first -

=item disabled - empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new internal access user.  To add the user to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_user'; }

sub _option_table    { 'access_user_pref'; }
sub _option_namecol  { 'prefname'; }
sub _option_valuecol { 'prefvalue'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  my $error = $self->check;
  return $error if $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->htpasswd_kludge();
  if ( $error ) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $error;
  }

  $error = $self->SUPER::insert(@_);

  if ( $error ) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;

    #make sure it isn't a dup username?  or you could nuke people's passwords
    #blah.  really just should do our own login w/cookies
    #and auth out of the db in the first place
    #my $hterror = $self->htpasswd_kludge('-D');
    #$error .= " - additionally received error cleaning up htpasswd file: $hterror"
    return $error;

  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    '';
  }

}

sub htpasswd_kludge {
  my $self = shift;
  
  #awful kludge to skip setting htpasswd for fs_* users
  return '' if $self->username =~ /^fs_/;

  unshift @_, '-c' unless -e $htpasswd_file;
  if ( 
       system('htpasswd', '-b', @_,
                          $htpasswd_file,
                          $self->username,
                          $self->_password,
             ) == 0
     )
  {
    return '';
  } else {
    return 'htpasswd exited unsucessfully';
  }
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error =
       $self->SUPER::delete(@_)
    || $self->htpasswd_kludge('-D')
  ;

  if ( $error ) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $error;
  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    '';
  }

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;

  my $old = ( ref($_[0]) eq ref($new) )
              ? shift
              : $new->replace_old;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $new->_password ne $old->_password ) {
    my $error = $new->htpasswd_kludge();
    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      return $error;
    }
  } elsif ( $old->disabled && !$new->disabled
              && $new->_password =~ /changeme/i ) {
    return "Must change password when enabling this account";
  }

  my $error = $new->SUPER::replace($old, @_);

  if ( $error ) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    return $error;
  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    '';
  }

}

=item check

Checks all fields to make sure this is a valid internal access user.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('usernum')
    || $self->ut_alpha_lower('username')
    || $self->ut_text('_password')
    || $self->ut_text('last')
    || $self->ut_text('first')
    || $self->ut_foreign_keyn('user_custnum', 'cust_main', 'custnum')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item name

Returns a name string for this user: "Last, First".

=cut

sub name {
  my $self = shift;
  $self->get('last'). ', '. $self->first;
}

=item user_cust_main

Returns the FS::cust_main object (see L<FS::cust_main>), if any, for this
user.

=cut

sub user_cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->user_custnum } );
}

=item access_usergroup

Returns links to the the groups this user is a part of, as FS::access_usergroup
objects (see L<FS::access_usergroup>).

=cut

sub access_usergroup {
  my $self = shift;
  qsearch( 'access_usergroup', { 'usernum' => $self->usernum } );
}

#=item access_groups
#
#=cut
#
#sub access_groups {
#
#}
#
#=item access_groupnames
#
#=cut
#
#sub access_groupnames {
#
#}

=item agentnums 

Returns a list of agentnums this user can view (via group membership).

=cut

sub agentnums {
  my $self = shift;
  my $sth = dbh->prepare(
    "SELECT DISTINCT agentnum FROM access_usergroup
                              JOIN access_groupagent USING ( groupnum )
       WHERE usernum = ?"
  ) or die dbh->errstr;
  $sth->execute($self->usernum) or die $sth->errstr;
  map { $_->[0] } @{ $sth->fetchall_arrayref };
}

=item agentnums_href

Returns a hashref of agentnums this user can view.

=cut

sub agentnums_href {
  my $self = shift;
  scalar( { map { $_ => 1 } $self->agentnums } );
}

=item agentnums_sql [ HASHREF | OPTION => VALUE ... ]

Returns an sql fragement to select only agentnums this user can view.

Options are passed as a hashref or a list.  Available options are:

=over 4

=item null

The frament will also allow the selection of null agentnums.

=item null_right

The fragment will also allow the selection of null agentnums if the current
user has the provided access right

=item table

Optional table name in which agentnum is being checked.  Sometimes required to
resolve 'column reference "agentnum" is ambiguous' errors.

=item viewall_right

All agents will be viewable if the current user has the provided access right.
Defaults to 'View customers of all agents'.

=back

=cut

sub agentnums_sql {
  my( $self ) = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  my $agentnum = $opt{'table'} ? $opt{'table'}.'.agentnum' : 'agentnum';

  my @or = ();

  my $viewall_right = $opt{'viewall_right'} || 'View customers of all agents';
  if ( $self->access_right($viewall_right) ) {
    push @or, "$agentnum IS NOT NULL";
  } else {
    push @or, "$agentnum IN (". join(',', $self->agentnums). ')';
  }

  push @or, "$agentnum IS NULL"
    if $opt{'null'}
    || ( $opt{'null_right'} && $self->access_right($opt{'null_right'}) );

  return ' 1 = 0 ' unless scalar(@or);
  '( '. join( ' OR ', @or ). ' )';

}

=item agentnum

Returns true if the user can view the specified agent.

=cut

sub agentnum {
  my( $self, $agentnum ) = @_;
  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM access_usergroup
                     JOIN access_groupagent USING ( groupnum )
       WHERE usernum = ? AND agentnum = ?"
  ) or die dbh->errstr;
  $sth->execute($self->usernum, $agentnum) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item agents

Returns the list of agents this user can view (via group membership), as
FS::agent objects.

=cut

sub agents {
  my $self = shift;
  qsearch({
    'table'     => 'agent',
    'hashref'   => { disabled=>'' },
    'extra_sql' => ' AND '. $self->agentnums_sql,
  });
}

=item access_right RIGHTNAME | LISTREF

Given a right name or a list reference of right names, returns true if this
user has this right, or, for a list, one of the rights (currently via group
membership, eventually also via user overrides).

=cut

sub access_right {
  my( $self, $rightname ) = @_;

  $rightname = [ $rightname ] unless ref($rightname);

  warn "$me access_right called on ". join(', ', @$rightname). "\n"
    if $DEBUG;

  #some caching of ACL requests for low-hanging fruit perf improvement
  #since we get a new $CurrentUser object each page view there shouldn't be any
  #issues with stickiness
  if ( $self->{_ACLcache} ) {

    unless ( grep !exists($self->{_ACLcache}{$_}), @$rightname ) {
      warn "$me ACL cache hit for ". join(', ', @$rightname). "\n"
        if $DEBUG;
      return grep $self->{_ACLcache}{$_}, @$rightname
    }

    warn "$me ACL cache miss for ". join(', ', @$rightname). "\n"
      if $DEBUG;

  } else {

    warn "initializing ACL cache\n"
      if $DEBUG;
    $self->{_ACLcache} = {};

  }

  my $has_right = ' rightname IN ('. join(',', map '?', @$rightname ). ') ';

  my $sth = dbh->prepare("
    SELECT groupnum FROM access_usergroup
                    LEFT JOIN access_group USING ( groupnum )
                    LEFT JOIN access_right
                         ON ( access_group.groupnum = access_right.rightobjnum )
      WHERE usernum = ?
        AND righttype = 'FS::access_group'
        AND $has_right
      LIMIT 1
  ") or die dbh->errstr;
  $sth->execute($self->usernum, @$rightname) or die $sth->errstr;
  my $row = $sth->fetchrow_arrayref;

  my $return = $row ? $row->[0] : '';

  #just caching the single-rightname hits should be enough of a win for now
  if ( scalar(@$rightname) == 1 ) {
    $self->{_ACLcache}{${$rightname}[0]} = $return;
  }

  $return;

}

=item default_customer_view

Returns the default customer view for this user, from the 
"default_customer_view" user preference, the "cust_main-default_view" config,
or the hardcoded default, "jumbo" (may change to "basics" in the near future).

=cut

sub default_customer_view {
  my $self = shift;

  $self->option('default_customer_view')
    || $conf->config('cust_main-default_view')
    || 'jumbo'; #'basics' in 1.9.1?

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

