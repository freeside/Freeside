package FS::SelfService;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $socket %autoload );
use Exporter;
use Socket;
use FileHandle;
#use IO::Handle;
use IO::Select;
use Storable qw(nstore_fd fd_retrieve);

$VERSION = '0.03';

@ISA = qw( Exporter );

$socket =  "/usr/local/freeside/selfservice_socket";

%autoload = (
  'passwd'        => 'passwd/passwd',
  'chfn'          => 'passwd/passwd',
  'chsh'          => 'passwd/passwd',
  'login'         => 'MyAccount/login',
  'customer_info' => 'MyAccount/customer_info',
  'invoice'       => 'MyAccount/invoice',
);
@EXPORT_OK = keys %autoload;

$ENV{'PATH'} ='/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n" if $> != $freeside_uid;

=head1 NAME

FS::SelfService - Freeside self-service API

=head1 SYNOPSIS

=head1 DESCRIPTION

Use this API to implement your own client "self-service" module.

If you just want to customize the look of the existing "self-service" module,
see XXXX instead.

=head1 FUNCTIONS

=over 4

=item passwd

Returns the empty value on success, or an error message on errors.

=cut

foreach my $autoload ( keys %autoload ) {

  my $eval =
  "sub $autoload { ". '
                   my $param;
                   if ( ref($_[0]) ) {
                     $param = shift;
                   } else {
                     $param = { @_ };
                   }

                   $param->{_packet} = \''. $autoload{$autoload}. '\';

                   simple_packet($param);
                 }';

  eval $eval;
  die $@ if $@;

}

sub simple_packet {
  my $packet = shift;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($socket)) or die "connect: $!";
  nstore_fd($packet, \*SOCK) or die "can't send packet: $!";
  SOCK->flush;

  #shoudl trap: Magic number checking on storable file failed at blib/lib/Storable.pm (autosplit into blib/lib/auto/Storable/fd_retrieve.al) line 337, at /usr/local/share/perl/5.6.1/FS/SelfService.pm line 71

  #block until there is a message on socket
#  my $w = new IO::Select;
#  $w->add(\*SOCK);
#  my @wait = $w->can_read;
  my $return = fd_retrieve(\*SOCK) or die "error reading result: $!";
  die $return->{'_error'} if defined $return->{_error} && $return->{_error};

  $return;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<freeside-selfservice-clientd>, L<freeside-selfservice-server>

=cut

1;

