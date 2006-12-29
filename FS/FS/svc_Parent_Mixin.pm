package FS::svc_Parent_Mixin;

use strict;
use NEXT;
use FS::Record qw(qsearch qsearchs);
use FS::cust_svc;

=head1 NAME

FS::svc_Parent_Mixin - Mixin class for svc_ classes with a parent_svcnum field

=head1 SYNOPSIS

package FS::svc_table;
use vars qw(@ISA);
@ISA = qw( FS::svc_Parent_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that contain a parent_svcnum field.

=cut

=head1 METHODS

=over 4

=item parent_cust_svc

Returns the parent FS::cust_svc object.

=cut

sub parent_cust_svc {
  my $self = shift;
  qsearchs('cust_svc', { 'svcnum' => $self->parent_svcnum } );
}

=item parent_svc_x

Returns the corresponding parent FS::svc_ object.

=cut

sub parent_svc_x {
  my $self = shift;
  $self->parent_cust_svc->svc_x;
}

=item children_cust_svc

Returns a list of any child FS::cust_svc objects.

Note: This is not recursive; it only returns direct children.

=cut

sub children_cust_svc { 
  my $self = shift;
  qsearch('cust_svc', { 'parent_svcnum' => $self->svcnum } );
}

=item children_svc_x

Returns the corresponding list of child FS::svc_ objects.

=cut

sub children_svc_x {
  my $self = shift;
  map { $_->svc_x } $self->children_cust_svc;
}

=item check

This class provides a check subroutine which takes care of checking the
parent_svcnum field.  The svc_ class which uses it will call SUPER::check at
the end of its own checks, and this class will call NEXT::check to pass 
the check "up the chain" (see L<NEXT>).

=cut

sub check {
  my $self = shift;

  $self->ut_foreign_keyn('parent_svcnum', 'cust_svc', 'svcnum')
    || $self->NEXT::check;

}

=back

=head1 BUGS

Do we need a recursive child finder for multi-layered children?

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>

=cut

1;
