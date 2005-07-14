package FS::cust_main_Mixin;

use strict;
use FS::cust_main;

=head1 NAME

FS::cust_main_Mixin - Mixin class for records that contain fields from cust_main

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that contain fields from the cust_main table,
for example, from a JOINed search.  See httemplate/search/ for examples.

=head1 METHODS

=over 4

=item name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<name> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub cust_unlinked_msg { '(unlinked)'; }
sub cust_linked { $_[0]->custnum; }

sub name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::name($self)
    : $self->cust_unlinked_msg;
}

=item ship_name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_name> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_name($self)
    : $self->cust_unlinked_msg;
}

=item contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<contact> method, or "(unlinked)" if this object is not linked
to a customer.

=cut

sub contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::contact($self)
    : $self->cust_unlinked_msg;
}

=item ship_contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_contact> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_contact($self)
    : $self->cust_unlinked_msg;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

