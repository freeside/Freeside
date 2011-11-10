package FS::svc_Radius_Mixin;

use strict;
use base qw(FS::m2m_Common FS::svc_Common);
use FS::Record qw(qsearch);
use FS::radius_group;
use FS::radius_usergroup;
use Carp qw(confess);

=head1 NAME

FS::svc_Radius_Mixin - partial base class for services with RADIUS groups

=cut


sub insert {
  my $self = shift;
  $self->SUPER::insert(@_)
  || $self->process_m2m(
    'link_table' => 'radius_usergroup',
    'target_table' => 'radius_group',
    'params' => $self->usergroup,
  );
}

sub replace  {
  my $new = shift;
  my $old = shift;
  $old = $new->replace_old if !defined($old);

  $old->usergroup; # make sure this is cached for exports
  $new->process_m2m(
    'link_table' => 'radius_usergroup',
    'target_table' => 'radius_group',
    'params' => $new->usergroup,
  ) || $new->SUPER::replace($old, @_);
}

sub delete {
  my $self = shift;
  $self->SUPER::delete(@_)
  || $self->process_m2m(
    'link_table' => 'radius_usergroup',
    'target_table' => 'radius_group',
    'params' => [],
  );
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

1;
