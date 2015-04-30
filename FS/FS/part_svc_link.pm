package FS::part_svc_link;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearchs ); # qw( qsearch qsearchs );

=head1 NAME

FS::part_svc_link - Object methods for part_svc_link records

=head1 SYNOPSIS

  use FS::part_svc_link;

  $record = new FS::part_svc_link \%hash;
  $record = new FS::part_svc_link { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_svc_link object represents an service definition dependency.
FS::part_svc_link inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item svclinknum

primary key

=cut

#=item linkname
#
#Dependency name

=item agentnum

Empty for global dependencies, or agentnum (see L<FS::agent>) for
agent-specific dependencies

=item src_svcpart

Source service definition (see L<FS::part_svc>)

=item dst_svcpart

Destination service definition (see L<FS::part_svc>)

=item link_type

Link type:

=over 4

=cut

# XXX false laziness w/edit/part_svc_link.html

=item part_pkg_restrict

In package defintions, require the destination service definition when the
source service definition is included

=item part_pkg_restrict_soft

Soft order block: in package definitions,  suggest the destination service definition when the source service definition is included

=item cust_svc_provision_restrict

Require the destination service to be provisioned before the source service

=item cust_svc_unprovision_restrict

Require the destination service to be unprovisioned before the source service

=item cust_svc_unprovision_cascade

Automatically unprovision the destination service when the source service is
unprovisioned

=item cust_svc_suspend_cascade

Suspend the destination service before the source service

=back

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_svc_link'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('svclinknum')
    #|| $self->ut_textn('linkname')
    || $self->ut_number('src_svcpart')
    || $self->ut_number('dst_svcpart')
    || $self->ut_text('link_type')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item description

Returns an extended description of this dependency, including.  Exact wording
depends on I<link_type>.

=cut

sub description {
  my $self = shift;

  my $src = $self->src_part_svc->svc;
  my $dst = $self->dst_part_svc->svc;

  #maybe sub-classes with overrides at some point
  #  (and hooks each place we have manual checks for the various rules)
  # but this will do for now

  $self->link_type eq 'part_pkg_restrict'
   and return "In package definitions, $dst is required when $src is included";

  $self->link_type eq 'part_pkg_restrict_soft'
   and return "In package definitions, $dst is suggested when $src is included";

  $self->link_type eq 'cust_svc_provision_restrict'
   and return "Require $dst provisioning before $src";

  $self->link_type eq 'cust_svc_unprovision_restrict'
   and return "Require $dst unprovisioning before $src";

  $self->link_type eq 'cust_svc_unprovision_cascade'
   and return "Automatically unprovision $dst when $src is unprovisioned";

  $self->link_type eq 'cust_svc_suspend_cascade'
   and return "Suspend $dst before $src";

  warn "WARNING: unknown part_svc_link.link_type ". $self->link_type. "\n";
  return "$src (unknown link_type ". $self->link_type. ") $dst";

}

=item src_part_svc 

Returns the source service definition, as an FS::part_svc object (see
L<FS::part_svc>).

=cut

sub src_part_svc {
  my $self = shift;
  qsearchs('part_svc', { svcpart=>$self->src_svcpart } );
}

=item src_svc

Returns the source service definition name (part_svc.svc).

=cut

sub src_svc {
  shift->src_part_svc->svc;
}

=item dst_part_svc

Returns the destination service definition, as an FS::part_svc object (see
L<FS::part_svc>).

=cut

sub dst_part_svc {
  my $self = shift;
  qsearchs('part_svc', { svcpart=>$self->dst_svcpart } );
}

=item dst_svc

Returns the destination service definition name (part_svc.svc).

=cut

sub dst_svc {
  shift->dst_part_svc->svc;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_svc>, L<FS::Record>

=cut

1;

