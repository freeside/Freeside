package FS::svc_CGPRule_Mixin;

use strict;
use FS::Record qw(qsearch);
use FS::cgp_rule;

=head1 NAME

FS::svc_CGPRule_Mixin - Mixin class for svc_classes which can be related to cgp_rule

=head1 SYNOPSIS

package FS::svc_table;
use base qw( FS::svc_CGPRule_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that can have Communigate Pro rules
(currently, domains and accounts).

=head1 METHODS

=over 4

=item cgp_rule

Returns the rules associated with this service, as FS::cgp_rule objects.

=cut

sub cgp_rule {
  my $self = shift;
  qsearch({
    'table'    => 'cgp_rule',
    'hashref'  => { 'svcnum' => $self->svcnum },
    'order_by' => 'ORDER BY priority ASC',
  });
}

=item cgp_rule_arrayref

Returns an arrayref of rules suitable for Communigate Pro API commands.

=cut

sub cgp_rule_arrayref {
  my $self = shift;
  [ map $_->arrayref, $self->cgp_rule ];
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cgp_rule>

=cut

1;
