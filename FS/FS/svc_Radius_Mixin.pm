package FS::svc_Radius_Mixin;
use base qw( FS::m2m_Common FS::svc_Common );

use strict;
use FS::Record qw( qsearch dbh );
use FS::radius_group;
use FS::radius_usergroup;
use Carp qw( confess );

# not really a mixin since it overrides insert/replace/delete and has svc_Common
#  as a base class, should probably be renamed svc_Radius_Common

=head1 NAME

FS::svc_Radius_Mixin - partial base class for services with RADIUS groups

=head1 METHODS

=over 4

=cut

sub insert {
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

  my $error =  $self->SUPER::insert(@_)
            || $self->process_m2m(
                                   'link_table'   => 'radius_usergroup',
                                   'target_table' => 'radius_group',
                                   'params'       => $self->usergroup,
                                 );

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

sub replace  {
  my $new = shift;
  my $old = shift;
  $old = $new->replace_old if !defined($old);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $old->usergroup; # make sure this is cached for exports

  my $error =  $new->check # make sure fixed fields are set before process_m2m
            || $new->process_m2m(
                                 'link_table'   => 'radius_usergroup',
                                 'target_table' => 'radius_group',
                                 'params'       => $new->usergroup,
                               )
            || $new->SUPER::replace($old, @_);

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

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

  my $error =  $self->SUPER::delete(@_)
            || $self->process_m2m(
                                   'link_table'   => 'radius_usergroup',
                                   'target_table' => 'radius_group',
                                   'params'       => [],
                                 );

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

sub usergroup {
  my $self = shift;
  my $value = shift;
  if ( defined $value ) {
    if ( ref $value ) {
      return $self->set('usergroup', $value);
    }
    else {
      return $self->set('usergroup', [ split(/\s*,\s*/, $value) ]);
    }
  }
  $self->get('usergroup') || 
    # if no argument is passed and usergroup is not set already, 
    # fetch this service's group assignments
  $self->set('usergroup', 
    [ map { $_->groupnum } 
        qsearch('radius_usergroup', { svcnum => $self->svcnum }) ]
  );
}

sub _fieldhandlers {
  { 
    'usergroup' => \&usergroup
  }
}

=item radius_groups METHOD

Returns a list of RADIUS groups for this service (see L<FS::radius_usergroup>).
METHOD is the field to return, and can be any method on L<FS::radius_group>.
Useful values for METHOD include 'groupnum', 'groupname', and 
'long_description'.  Defaults to 'groupname' for historical reasons.

=cut

sub radius_groups {
  my $self = shift;
  my $method = shift || 'groupname';
  my $groups = join(',', @{$self->usergroup}) || return ();
  my @groups = qsearch({'table' => 'radius_group',
                        'extra_sql' => "where groupnum in ($groups)"});
  return map {$_->$method} @groups;
}

=item seconds_since_sqlradacct TIMESTAMP_START TIMESTAMP_END

Returns the numbers of seconds this account has been online between
TIMESTAMP_START (inclusive) and TIMESTAMP_END (exclusive), according to an
external SQL radacct table, specified via sqlradius export.  Sessions which
started in the specified range but are still open are counted from session
start to the end of the range (unless they are over 1 day old, in which case
they are presumed missing their stop record and not counted).  Also, sessions
which end in the range but started earlier are counted from the start of the
range to session end.  Finally, sessions which start before the range but end
after are counted for the entire range.

TIMESTAMP_START and TIMESTAMP_END are specified as UNIX timestamps; see
L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

=cut

#note: POD here, implementation in FS::cust_svc
sub seconds_since_sqlradacct {
  my $self = shift;
  $self->cust_svc->seconds_since_sqlradacct(@_);
}

=item attribute_since_sqlradacct TIMESTAMP_START TIMESTAMP_END ATTRIBUTE

For this service, returns the sum of the given attribute for sessions ending
between TIMESTAMP_START (inclusive) and TIMESTAMP_END (exclusive).

TIMESTAMP_START and TIMESTAMP_END are specified as UNIX timestamps; see
L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

=cut

#note: POD here, implementation in FS::cust_svc
sub attribute_since_sqlradacct {
  my $self = shift;
  $self->cust_svc->attribute_since_sqlradacct(@_);
}

=item attribute_last_sqlradacct ATTRIBUTE

For this service, returns the most recent value of the given attribute.

=cut

#note: POD here, implementation in FS::cust_svc
sub attribute_last_sqlradacct {
  my $self = shift;
  $self->cust_svc->attribute_last_sqlradacct(@_);
}
=item get_session_history TIMESTAMP_START TIMESTAMP_END

Returns an array of hash references of this customers login history for the
given time range.  (document this better)

=cut

sub get_session_history {
  my $self = shift;
  $self->cust_svc->get_session_history(@_);
}


=back

=cut

1;
