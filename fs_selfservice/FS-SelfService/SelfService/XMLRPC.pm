package FS::SelfService::XMLRPC;

=head1 NAME

FS::SelfService::XMLRPC - Freeside XMLRPC accessible self-service API

=head1 SYNOPSIS

=head1 DESCRIPTION

Use this API to implement your own client "self-service" module vi XMLRPC.

Each routine described in L<FS::SelfService> is available vi XMLRPC as the
method FS.SelfService.XMLRPC.B<method>.  All values are passed to the
selfservice-server in a struct of strings.  The return values are in a
struct as strings, arrays, or structs as appropriate for the values
described in L<FS::SelfService>.

=head1 BUGS

=head1 SEE ALSO

L<freeside-selfservice-clientd>, L<freeside-selfservice-server>,L<FS::SelfService>

=cut

use strict;
use vars qw($DEBUG $AUTOLOAD);
use XMLRPC::Lite; # for XMLRPC::Data
use FS::SelfService;

$DEBUG = 0;
$FS::SelfService::DEBUG = $DEBUG;

#false laziness w/FS::ClientAPI_XMLRPC.pm
our %typefix = (
  'invoice_pdf'        => { 'invoice_pdf' => 'base64', },
  'legacy_invoice_pdf' => { 'invoice_pdf' => 'base64', },
  'skin_info'          => { 'logo'              => 'base64',
                            'title_left_image'  => 'base64',
                            'title_right_image' => 'base64',
                            'menu_top_image'    => 'base64',
                            'menu_body_image'   => 'base64',
                            'menu_bottom_image' => 'base64',
                          },
  'invoice_logo'       => { 'logo' => 'base64', },
);

sub AUTOLOAD {
  my $call = $AUTOLOAD;
  $call =~ s/^FS::SelfService::XMLRPC:://;

  if (exists($FS::SelfService::autoload{$call})) {

    shift; #discard package name;

    $call = "FS::SelfService::$call";

    no strict 'refs';

    my $return = &{$call}(@_);

    if ( exists($typefix{$call}) ) {
      my $typefix = $typefix{$call};
      foreach my $field ( grep exists($return->{$_}), keys %$typefix ) {
        my $type = $typefix->{$field};
        $return->{$field} = XMLRPC::Data->value($return->{$field})
                                        ->type($type);
      }
    }

    $return;

  }else{
    die "No such procedure: $call";
  }
}

package SOAP::Transport::HTTP::Daemon;  # yuck

use POSIX qw(:sys_wait_h);

no warnings 'redefine';

sub handle {
  my $self = shift->new;

  local $SIG{CHLD} = 'IGNORE';

ACCEPT:
  while (my $c = $self->accept) {
    
    my $kid = 0;
    do {
      $kid = waitpid(-1, WNOHANG);
      warn "found kid $kid";
    } while $kid > 0;

    my $pid = fork;
    next ACCEPT if $pid;

    if ( not defined $pid ) {
      warn "fork() failed: $!";
      $c = undef;
    } else {
      while (my $r = $c->get_request) {
        $self->request($r);
        $self->SUPER::handle;
        $c->send_response($self->response);
      }
      # replaced ->close, thanks to Sean Meisner <Sean.Meisner@VerizonWireless.com>
      # shutdown() doesn't work on AIX. close() is used in this case. Thanks to Jos Clijmans <jos.clijmans@recyfin.be>
      UNIVERSAL::isa($c, 'shutdown') ? $c->shutdown(2) : $c->close(); 
      $c->close;
    }
    exit;
  }
}

1;
