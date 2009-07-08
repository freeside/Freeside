#!/usr/bin/perl

package HTML::Mason;

use strict;
use warnings;
use FS::Mason qw( mason_interps );

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

sub handler
{
    #($r) = @_;
    my $r = shift;

    # If you plan to intermix images in the same directory as
    # components, activate the following to prevent Mason from
    # evaluating image files as components.
    #
    #return -1 if $r->content_type && $r->content_type !~ m|^text/|i;

    ###Module::Refresh->refresh;###

    $r->content_type('text/html');
    #eorar

    my $headers = $r->headers_out;
    $headers->{'Cache-control'} = 'no-cache';
    #$r->no_cache(1);
    $headers->{'Expires'} = '0';

#    $r->send_http_header;

    if ( $r->filename =~ /\/rt\// ) { #RT

      $ah->interp($rt_interp);

      local $SIG{__WARN__};
      local $SIG{__DIE__};

      RT::Init();

      # We don't need to handle non-text, non-xml items
      return -1 if defined( $r->content_type )
                && $r->content_type !~ m!(^text/|\bxml\b)!io;

    } else {

      RT::Init() if $RT::VERSION; #for lack of something else

      $ah->interp($fs_interp);

    }

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

    $status;
}

1;
