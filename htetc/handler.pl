#!/usr/bin/perl
#
# This is a basic, fairly fuctional Mason handler.pl.
#
# For something a little more involved, check out session_handler.pl

package HTML::Mason;

# Bring in main Mason package.
use HTML::Mason;

# Bring in ApacheHandler, necessary for mod_perl integration.
# Uncomment the second line (and comment the first) to use
# Apache::Request instead of CGI.pm to parse arguments.
use HTML::Mason::ApacheHandler;
# use HTML::Mason::ApacheHandler (args_method=>'mod_perl');

# Uncomment the next line if you plan to use the Mason previewer.
#use HTML::Mason::Preview;

use strict;

# List of modules that you want to use from components (see Admin
# manual for details)
#{  package HTML::Mason::Commands;
#   use CGI;
#}

# Create Mason objects
#

#my $parser = new HTML::Mason::Parser;
#my $interp = new HTML::Mason::Interp (parser=>$parser,
#                                      comp_root=>'/var/www/masondocs',
#                                      data_dir=>'/usr/local/etc/freeside/masondata',
#                                      out_mode=>'stream',
#                                     );
my $ah = new HTML::Mason::ApacheHandler (
  #interp => $interp,
  #auto_send_headers => 0,
  comp_root=>'/var/www/freeside',
  data_dir=>'/usr/local/etc/freeside/masondata',
  #out_mode=>'stream',
);

# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
#chown (Apache->server->uid, Apache->server->gid, $interp->files_written);

sub handler
{
    my ($r) = @_;

    # If you plan to intermix images in the same directory as
    # components, activate the following to prevent Mason from
    # evaluating image files as components.
    #
    #return -1 if $r->content_type && $r->content_type !~ m|^text/|i;

    #rar
    { package HTML::Mason::Commands;
      use strict;
      use vars qw( $cgi $p );
      use CGI;
      #use CGI::Carp qw(fatalsToBrowser);
      use Date::Format;
      use Date::Parse;
      use Time::Local;
      use Tie::IxHash;
      use HTML::Entities;
      use IO::Handle;
      use IO::File;
      use String::Approx qw(amatch);
      use Chart::LinesPoints;
      use HTML::Widgets::SelectLayers 0.02;
      use FS::UID qw(cgisuidsetup dbh getotaker datasrc driver_name);
      use FS::Record qw(qsearch qsearchs fields dbdef);
      use FS::Conf;
      use FS::CGI qw(header menubar popurl table itable ntable idiot eidiot
                     small_custview myexit http_header);
      use FS::Msgcat qw(gettext geterror);

      use FS::agent;
      use FS::agent_type;
      use FS::domain_record;
      use FS::cust_bill;
      use FS::cust_bill_pay;
      use FS::cust_credit;
      use FS::cust_credit_bill;
      use FS::cust_main;
      use FS::cust_main_county;
      use FS::cust_pay;
      use FS::cust_pkg;
      use FS::cust_refund;
      use FS::cust_svc;
      use FS::nas;
      use FS::part_bill_event;
      use FS::part_pkg;
      use FS::part_referral;
      use FS::part_svc;
      use FS::part_svc_router;
      use FS::part_virtual_field;
      use FS::pkg_svc;
      use FS::port;
      use FS::queue qw(joblisting);
      use FS::raddb;
      use FS::session;
      use FS::svc_acct;
      use FS::svc_acct_pop qw(popselector);
      use FS::svc_acct_sm;
      use FS::svc_domain;
      use FS::svc_forward;
      use FS::svc_www;
      use FS::router;
      use FS::addr_block;
      use FS::svc_broadband;
      use FS::type_pkgs;
      use FS::part_export;
      use FS::part_export_option;
      use FS::export_svc;
      use FS::msgcat;

      *CGI::redirect = sub {
        my( $self, $location ) = @_;
        use vars qw($m);
        #http://www.masonhq.com/docs/faq/#how_do_i_do_an_external_redirect
        $m->clear_buffer;
        # The next two lines are necessary to stop Apache from re-reading
        # POSTed data.
        $r->method('GET');
        $r->headers_in->unset('Content-length');
        $r->content_type('text/html');
        #$r->err_header_out('Location' => $location);
        $r->header_out('Location' => $location);
         $r->header_out('Content-Type' => 'text/html');
         $m->abort(302);

        '';
      };

      $cgi = new CGI;
      &cgisuidsetup($cgi);
      #&cgisuidsetup($r);
      $p = popurl(2);
    }

    $r->content_type('text/html');
    #eorar

    my $headers = $r->headers_out;
    $headers->{'Pragma'} = $headers->{'Cache-control'} = 'no-cache';
    #$r->no_cache(1);
    $headers->{'Expires'} = '0';

#    $r->send_http_header;

    my $status = $ah->handle_request($r);

    $status;
}

1;
