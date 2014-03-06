package FS::Daemon::Preforking;
use base 'Exporter';

=head1 NAME

FS::Daemon::Preforking - A preforking web server

=head1 SYNOPSIS

  use FS::Daemon::Preforking qw( freeside_init1 freeside_init2 daemon_run );

  my $me = 'mydaemon'; #keep unique among fs daemons, for logfiles etc.

  freeside_init1($me); #daemonize, drop root and connect to freeside

  #do setup tasks which should throw an error to the shell starting the daemon

  freeside_init2($me); #move logging to logfile and disassociate from terminal

  #do setup tasks which will warn/error to the log file, such as declining to
  # run if our config is not in place

  daemon_run(
    'port'           => 5454, #keep unique among fs daemons
    'handle_request' => \&handle_request,
  );

  sub handle_request {
    my $request = shift; #HTTP::Request object

    #... do your thing

    return $response; #HTTP::Response object

  }

=head1 AUTHOR

Based on L<http://www.perlmonks.org/?node_id=582781> by Justin Hawkins

and L<http://poe.perl.org/?POE_Cookbook/Web_Server_With_Forking>

=cut

use warnings;
use strict;

use constant DEBUG         => 0;       # Enable much runtime information.
use constant MAX_PROCESSES => 10;      # Total server process count.
#use constant TESTING_CHURN => 0;       # Randomly test process respawning.

use vars qw( @EXPORT_OK $FREESIDE_LOG $SERVER_PORT $user $handle_request );
@EXPORT_OK = qw( freeside_init1 freeside_init2 daemon_run );
$FREESIDE_LOG = '%%%FREESIDE_LOG%%%';

use POE 1.2;                     # Base features.
use POE::Filter::HTTPD;          # For serving HTTP content.
use POE::Wheel::ReadWrite;       # For socket I/O.
use POE::Wheel::SocketFactory;   # For serving socket connections.

use FS::Daemon qw( daemonize1 drop_root logfile daemonize2 );
use FS::UID qw( adminsuidsetup forksuidsetup dbh );

#use FS::TicketSystem;

sub freeside_init1 {
  my $name = shift;

  $user = shift @ARGV or die &usage($name);

  $FS::Daemon::NOSIG = 1;
  $FS::Daemon::PID_NEWSTYLE = 1;
  daemonize1($name);

  POE::Kernel->has_forked(); #daemonize forks...

  drop_root();

  adminsuidsetup($user);
}

sub freeside_init2 {
  my $name = shift;

  logfile("$FREESIDE_LOG/$name.log");

  daemonize2();

}

sub daemon_run {
  my %opt = @_;
  $SERVER_PORT = $opt{port};
  $handle_request = $opt{handle_request};

  #parent doesn't need to hold a DB connection open
  dbh->disconnect;
  undef $FS::UID::dbh;

  server_spawn(MAX_PROCESSES);
  POE::Kernel->run();
  #exit;

}

### Spawn the main server.  This will run as the parent process.

sub server_spawn {
    my ($max_processes) = @_;

    POE::Session->create(
      inline_states => {
        _start         => \&server_start,
        _stop          => \&server_stop,
        do_fork        => \&server_do_fork,
        got_error      => \&server_got_error,
        got_sig_int    => \&server_got_sig_int,
        got_sig_child  => \&server_got_sig_child,
        got_connection => \&server_got_connection,
        _child         => sub { undef },
      },
      heap => { max_processes => MAX_PROCESSES },
    );
}

### The main server session has started.  Set up the server socket and
### bookkeeping information, then fork the initial child processes.

sub server_start {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

    $heap->{server} = POE::Wheel::SocketFactory->new
      ( BindPort     => $SERVER_PORT,
        SuccessEvent => "got_connection",
        FailureEvent => "got_error",
        Reuse        => "yes",
      );

    $kernel->sig( INT  => "got_sig_int" );
    $kernel->sig( TERM => "got_sig_int" ); #huh

    $heap->{children}   = {};
    $heap->{is_a_child} = 0;

    warn "Server $$ has begun listening on port $SERVER_PORT\n";

    $kernel->yield("do_fork");
}

### The server session has shut down.  If this process has any
### children, signal them to shutdown too.

sub server_stop {
    my $heap = $_[HEAP];
    DEBUG and warn "Server $$ stopped.\n";

    if ( my @children = keys %{ $heap->{children} } ) {
        DEBUG and warn "Server $$ is signaling children to stop.\n";
        kill INT => @children;
    }
}

### The server session has encountered an error.  Shut it down.

sub server_got_error {
    my ( $heap, $syscall, $errno, $error ) = @_[ HEAP, ARG0 .. ARG2 ];
      warn( "Server $$ got $syscall error $errno: $error\n",
        "Server $$ is shutting down.\n",
      );
    delete $heap->{server};
}

### The server has a need to fork off more children.  Only honor that
### request form the parent, otherwise we would surely "forkbomb".
### Fork off as many child processes as we need.

sub server_do_fork {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

    return if $heap->{is_a_child};

    #my $current_children = keys %{ $heap->{children} };
    #for ( $current_children + 2 .. $heap->{max_processes} ) {
    while (scalar(keys %{$heap->{children}}) < $heap->{max_processes}) {

        DEBUG and warn "Server $$ is attempting to fork.\n";

        my $pid = fork();

        unless ( defined($pid) ) {
            DEBUG and
              warn( "Server $$ fork failed: $!\n",
                "Server $$ will retry fork shortly.\n",
              );
            $kernel->delay( do_fork => 1 );
            return;
        }

        # Parent.  Add the child process to its list.
        if ($pid) {
            $heap->{children}->{$pid} = 1;
            $kernel->sig_child($pid, "got_sig_child");
            next;
        }

        # Child.  Clear the child process list.
        $kernel->has_forked();
        DEBUG and warn "Server $$ forked successfully.\n";
        $heap->{is_a_child} = 1;
        $heap->{children}   = {};

        #freeside db connection, etc.
        forksuidsetup($user);

        #why isn't this needed ala freeside-selfservice-server??
        #FS::TicketSystem->init();

        return;
    }
}

### The server session received SIGINT.  Don't handle the signal,
### which in turn will trigger the process to exit gracefully.

sub server_got_sig_int {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    DEBUG and warn "Server $$ received SIGINT/TERM.\n";

    if ( my @children = keys %{ $heap->{children} } ) {
        DEBUG and warn "Server $$ is signaling children to stop.\n";
        kill INT => @children;
    }

    delete $heap->{server};
    $kernel->sig_handled();
}

### The server session received a SIGCHLD, indicating that some child
### server has gone away.  Remove the child's process ID from our
### list, and trigger more fork() calls to spawn new children.

sub server_got_sig_child {
    my ( $kernel, $heap, $child_pid ) = @_[ KERNEL, HEAP, ARG1 ];

    return unless delete $heap->{children}->{$child_pid};

   DEBUG and warn "Server $$ reaped child $child_pid.\n";
   $kernel->yield("do_fork") if exists $_[HEAP]->{server};
}

### The server session received a connection request.  Spawn off a
### client handler session to parse the request and respond to it.

sub server_got_connection {
    my ( $heap, $socket, $peer_addr, $peer_port ) = @_[ HEAP, ARG0, ARG1, ARG2 ];

    DEBUG and warn "Server $$ received a connection.\n";

    POE::Session->create(
      inline_states => {
        _start      => \&client_start,
        _stop       => \&client_stop,
        got_request => \&client_got_request,
        got_flush   => \&client_flushed_request,
        got_error   => \&client_got_error,
        _parent     => sub { 0 },
      },
      heap => {
        socket    => $socket,
        peer_addr => $peer_addr,
        peer_port => $peer_port,
      },
    );

#    # Gracefully exit if testing process churn.
#    delete $heap->{server}
#      if TESTING_CHURN and $heap->{is_a_child} and ( rand() < 0.1 );
}

### The client handler has started.  Wrap its socket in a ReadWrite
### wheel to begin interacting with it.

sub client_start {
    my $heap = $_[HEAP];

    $heap->{client} = POE::Wheel::ReadWrite->new
      ( Handle => $heap->{socket},
        Filter       => POE::Filter::HTTPD->new(),
        InputEvent   => "got_request",
        ErrorEvent   => "got_error",
        FlushedEvent => "got_flush",
      );

    DEBUG and warn "Client handler $$/", $_[SESSION]->ID, " started.\n";
}

### The client handler has stopped.  Log that fact.

sub client_stop {
    DEBUG and warn "Client handler $$/", $_[SESSION]->ID, " stopped.\n";
}

### The client handler has received a request.  If it's an
### HTTP::Response object, it means some error has occurred while
### parsing the request.  Send that back and return immediately.
### Otherwise parse and process the request, generating and sending an
### HTTP::Response object in response.

sub client_got_request {
    my ( $heap, $request ) = @_[ HEAP, ARG0 ];

    DEBUG and
      warn "Client handler $$/", $_[SESSION]->ID, " is handling a request.\n";

    if ( $request->isa("HTTP::Response") ) {
        $heap->{client}->put($request);
        return;
   }

    forksuidsetup($user) unless dbh && dbh->ping;

    my $response = &{ $handle_request }( $request );

    $heap->{client}->put($response);
}

### The client handler received an error.  Stop the ReadWrite wheel,
### which also closes the socket.

sub client_got_error {
    my ( $heap, $operation, $errnum, $errstr ) = @_[ HEAP, ARG0, ARG1, ARG2 ];
    DEBUG and
      warn( "Client handler $$/", $_[SESSION]->ID,
        " got $operation error $errnum: $errstr\n",
        "Client handler $$/", $_[SESSION]->ID, " is shutting down.\n"
      );
    delete $heap->{client};
}

### The client handler has flushed its response to the socket.  We're
### done with the client connection, so stop the ReadWrite wheel.

sub client_flushed_request {
    my $heap = $_[HEAP];
    DEBUG and
      warn( "Client handler $$/", $_[SESSION]->ID,
        " flushed its response.\n",
        "Client handler $$/", $_[SESSION]->ID, " is shutting down.\n"
      );
    delete $heap->{client};
}

sub usage {
  my $name = shift;
  die "Usage:\n\n  freeside-$name user\n";
}

1;
