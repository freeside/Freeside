package FS::h_svc_alarm;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_alarm;

@ISA = qw( FS::h_Common FS::svc_alarm );

sub table { 'h_svc_alarm' };

=head1 NAME

FS::h_svc_alarm - Historical Alarm service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_alarm object represents a historical alarm service subscriber.
FS::h_svc_alarm inherits from FS::h_Common and FS::svc_alarm.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_alarm>, L<FS::Record>

=cut

1;

