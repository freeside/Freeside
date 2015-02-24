#!/usr/bin/perl

package HTML::Mason;

use strict;
use warnings;
use FS::Mason qw( mason_interps );
use FS::Trace;
use FS::Conf;

$FS::Conf::conf_cache_enabled = 1; # enable FS::Conf caching for performance

if ( %%%RT_ENABLED%%% ) {

  require RT;

  $> = scalar(getpwnam('freeside'));

  RT::LoadConfig();
  RT::Init();

  # disconnect DB before fork:
  #   (avoid 'prepared statement "dbdpg_p\d+_\d+" already exists' errors?)
  $RT::Handle->dbh(undef);
  undef $RT::Handle;

  $> = $<;
}

#use vars qw($r);

# Bring in ApacheHandler, necessary for mod_perl integration.
# Uncomment the second line (and comment the first) to use
# Apache::Request instead of CGI.pm to parse arguments.
use HTML::Mason::ApacheHandler;
# use HTML::Mason::ApacheHandler (args_method=>'mod_perl');

###use Module::Refresh;###

# Create Mason objects

my( $fs_interp, $rt_interp ) = mason_interps('apache');

my $ah = new HTML::Mason::ApacheHandler (
  interp        => $fs_interp,
  request_class => 'FS::Mason::Request',
  args_method   => 'CGI', #(and FS too)
);

# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
#chown (Apache->server->uid, Apache->server->gid, $interp->files_written);

my $protect_fds;

sub handler
{
    #($r) = @_;
    my $r = shift;

    FS::Trace->log('protecting fds');

    #from rt/bin/webmux.pl(.in)
    if ( !$protect_fds && $ENV{'MOD_PERL'} && exists $ENV{'MOD_PERL_API_VERSION'}
        && $ENV{'MOD_PERL_API_VERSION'} >= 2
    ) {
        # under mod_perl2, STDIN and STDOUT get closed and re-opened,
        # however they are not on FD 0 and 1.  In this case, the next
        # socket that gets opened will occupy one of these FDs, and make
        # all system() and open "|-" calls dangerous; for example, the
        # DBI handle can get this FD, which later system() calls will
        # close by putting garbage into the socket.
        $protect_fds = [];
        push @{$protect_fds}, IO::Handle->new_from_fd(0, "r")
            if fileno(STDIN) != 0;
        push @{$protect_fds}, IO::Handle->new_from_fd(1, "w")
            if fileno(STDOUT) != 1;
    }

    # If you plan to intermix images in the same directory as
    # components, activate the following to prevent Mason from
    # evaluating image files as components.
    #
    #return -1 if $r->content_type && $r->content_type !~ m|^text/|i;

    ###Module::Refresh->refresh;###

    FS::Trace->log('setting content_type / headers');

    $r->content_type('text/html; charset=utf-8');
    #$r->content_type('text/html; charset=iso-8859-1');
    #eorar

    my $headers = $r->headers_out;
    $headers->{'Cache-control'} = 'no-cache';
    #$r->no_cache(1);
    $headers->{'Expires'} = '0';

#    $r->send_http_header;

    if ( $r->filename =~ /\/rt\// ) { #RT

      FS::Trace->log('handling RT file');

      # We don't need to handle non-text, non-xml items
      return -1 if defined( $r->content_type )
                && $r->content_type !~ m!(^text/|\bxml\b)!io;


      local $SIG{__WARN__};
      local $SIG{__DIE__};

      FS::Trace->log('initializing RT');
      my_rt_init();

      FS::Trace->log('setting RT interpreter');
      $ah->interp($rt_interp);

    } else {

      FS::Trace->log('handling Freeside file');

      local $SIG{__WARN__};
      local $SIG{__DIE__};

      FS::Trace->log('initializing RT');
      my_rt_init();

      #we don't want the RT error handlers under FS
      {
        no warnings 'uninitialized';
        undef($SIG{__WARN__}) if defined($SIG{__WARN__});
        undef($SIG{__DIE__})  if defined($SIG{__DIE__} );
      }

      FS::Trace->log('setting Freeside interpreter');
      $ah->interp($fs_interp);

    }

    FS::Trace->log('handling request');
    my %session;
    my $status;
    eval { $status = $ah->handle_request($r); };
#!!
#    if ( $@ ) {
#	$RT::Logger->crit($@);
#    }
    warn $@ if $@;

    undef %session;

#!!
#    if ($RT::Handle->TransactionDepth) {
#	$RT::Handle->ForceRollback;
#    	$RT::Logger->crit(
#"Transaction not committed. Usually indicates a software fault. Data loss may have occurred"
#       );
#    }

    FS::Trace->log('done');

    FS::Trace->dumpfile( "%%%FREESIDE_EXPORT%%%/profile/$$.".time,
                         FS::Trace->total. ' '. $r->filename
                       )
      if FS::Trace->total > 5; #10?

    FS::Trace->reset;

    $status;
}

sub my_rt_init {
  return unless $RT::VERSION;
  RT::ConnectToDatabase();
  RT::InitSignalHandlers();
}

1;
