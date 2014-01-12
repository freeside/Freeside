package FS::svc_PBX_Mixin;

use strict;
use FS::Record qw( qsearchs ); # qw(qsearch qsearchs);
use FS::svc_pbx;

=head1 NAME

FS::svc_PBX_Mixin - Mixin class for svc_classes with a pbxsvc field

=head1 SYNOPSIS

package FS::svc_table;
use base qw( FS::svc_PBX_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that contain a pbxsvc field linking to
a PBX (see L<FS::svc_pbx>).

=head1 METHODS

=over 4

=item svc_pbx

Returns the FS::svc_pbx record for this account's domain (see
L<FS::svc_pbx>).

=cut

# FS::h_svc_acct has a history-aware svc_domain override

sub svc_pbx {
  my $self = shift;
  #$self->{'_pbxsvc'}
  #  ? $self->{'_pbxsvc'}
  #  :
      qsearchs( 'svc_pbx', { 'svcnum' => $self->pbxsvc } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>

=cut

1;
