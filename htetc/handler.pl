#!/usr/bin/perl
#
# This is a basic, fairly fuctional Mason handler.pl.
#
# For something a little more involved, check out session_handler.pl

package HTML::Mason;

# Bring in main Mason package.
use HTML::Mason 1.1;

# Bring in ApacheHandler, necessary for mod_perl integration.
# Uncomment the second line (and comment the first) to use
# Apache::Request instead of CGI.pm to parse arguments.
use HTML::Mason::ApacheHandler;
# use HTML::Mason::ApacheHandler (args_method=>'mod_perl');

# Uncomment the next line if you plan to use the Mason previewer.
#use HTML::Mason::Preview;

use strict;

###use Module::Refresh;###

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

use vars qw($r);

if ( %%%RT_ENABLED%%% ) {
 eval '
   use lib ( "/opt/rt3/local/lib", "/opt/rt3/lib" );
   use RT;
   use vars qw($Nobody $SystemUser);
   RT::LoadConfig();
 ';
 die $@ if $@;


}


my $ah = new HTML::Mason::ApacheHandler (
  #interp => $interp,
  #auto_send_headers => 0,
  comp_root=> [
                [ 'freeside' => '%%%FREESIDE_DOCUMENT_ROOT%%%'    ],
                [ 'rt'       => '%%%FREESIDE_DOCUMENT_ROOT%%%/rt' ],
              ],
  data_dir=>'%%%MASONDATA%%%',
  #out_mode=>'stream',

  #RT
  args_method => 'CGI',
  default_escape_flags => 'h',
  allow_globals => [qw(%session)],
  #autoflush => 1,
);

# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
#chown (Apache->server->uid, Apache->server->gid, $interp->files_written);

sub handler
{
    ($r) = @_;

    # If you plan to intermix images in the same directory as
    # components, activate the following to prevent Mason from
    # evaluating image files as components.
    #
    #return -1 if $r->content_type && $r->content_type !~ m|^text/|i;

    #rar
    { package HTML::Mason::Commands;
      use strict;
      use vars qw( $cgi $p $fsurl);
      use vars qw( %session );
      use CGI 2.47 qw(-private_tempfiles);
      #use CGI::Carp qw(fatalsToBrowser);
      use List::Util qw( max min );
      use Date::Format;
      use Date::Parse;
      use Time::Local;
      use Time::Duration;
      use DateTime;
      use DateTime::Format::Strptime;
      use Lingua::EN::Inflect qw(PL);
      use Tie::IxHash;
      use URI::Escape;
      use HTML::Entities;
      use JSON;
      use IO::Handle;
      use IO::File;
      use IO::Scalar;
      use Net::Whois::Raw qw(whois);
      if ( $] < 5.006 ) {
        eval "use Net::Whois::Raw 0.32 qw(whois)";
        die $@ if $@;
      }
      use Text::CSV_XS;
      use Spreadsheet::WriteExcel;
      use Business::CreditCard 0.30; #for mask-aware cardtype()
      use String::Approx qw(amatch);
      use Chart::LinesPoints;
      use Chart::Mountain;
      use Color::Scheme;
      use HTML::Widgets::SelectLayers 0.06;
      #use HTML::Widgets::SelectLayers 0.07; # after 1.7.2
      use Locale::Country;
      use FS;
      use FS::UID qw(cgisuidsetup dbh getotaker datasrc driver_name);
      use FS::Record qw(qsearch qsearchs fields dbdef);
      use FS::Conf;
      use FS::CGI qw(header menubar popurl rooturl table itable ntable idiot
                     eidiot small_custview myexit http_header);
      use FS::UI::Web;
      use FS::Msgcat qw(gettext geterror);
      use FS::Misc qw( send_email send_fax states_hash counties state_label );
      use FS::Report::Table::Monthly;
      use FS::TicketSystem;

      use FS::agent;
      use FS::agent_type;
      use FS::domain_record;
      use FS::cust_bill;
      use FS::cust_bill_pay;
      use FS::cust_credit;
      use FS::cust_credit_bill;
      use FS::cust_main qw(smart_search);
      use FS::cust_main_county;
      use FS::cust_pay;
      use FS::cust_pkg;
      use FS::cust_pkg_reason;
      use FS::cust_refund;
      use FS::cust_svc;
      use FS::nas;
      use FS::part_bill_event;
      use FS::part_pkg;
      use FS::part_referral;
      use FS::part_svc;
      use FS::part_svc_router;
      use FS::part_virtual_field;
      use FS::pay_batch;
      use FS::pkg_svc;
      use FS::port;
      use FS::queue qw(joblisting);
      use FS::raddb;
      use FS::session;
      use FS::svc_acct;
      use FS::svc_acct_pop qw(popselector);
      use FS::svc_domain;
      use FS::svc_forward;
      use FS::svc_www;
      use FS::router;
      use FS::addr_block;
      use FS::svc_broadband;
      use FS::svc_external;
      use FS::type_pkgs;
      use FS::part_export;
      use FS::part_export_option;
      use FS::export_svc;
      use FS::msgcat;
      use FS::rate;
      use FS::rate_region;
      use FS::rate_prefix;
      use FS::payment_gateway;
      use FS::agent_payment_gateway;
      use FS::XMLRPC;
      use FS::payby;
      use FS::cdr;
      use FS::inventory_class;
      use FS::inventory_item;
      use FS::pkg_class;
      use FS::access_user;
      use FS::access_group;
      use FS::access_usergroup;
      use FS::access_groupagent;
      use FS::access_right;
      use FS::AccessRight;
      use FS::svc_phone;
      use FS::reason_type;
      use FS::reason;
      use FS::cust_main_note;

      if ( %%%RT_ENABLED%%% ) {
        eval '
          use RT::Tickets;
          use RT::Transactions;
          use RT::Users;
          use RT::CurrentUser;
          use RT::Templates;
          use RT::Queues;
          use RT::ScripActions;
          use RT::ScripConditions;
          use RT::Scrips;
          use RT::Groups;
          use RT::GroupMembers;
          use RT::CustomFields;
          use RT::CustomFieldValues;
          use RT::ObjectCustomFieldValues;

          use RT::Interface::Web;
          use MIME::Entity;
          use Text::Wrapper;
          use CGI::Cookie;
          use Time::ParseDate;
          use HTML::Scrubber;
          use Text::Quoted;
        ';
        die $@ if $@;
      }

      *CGI::redirect = sub {
        my( $self, $location ) = @_;
        use vars qw($m);

        # false laziness w/below
        if ( defined(@DBIx::Profile::ISA) ) { #profiling redirect

          my $page =
            qq!<HTML><BODY>Redirect to <A HREF="$location">$location</A>!.
            '<BR><BR><PRE>'.
              ( UNIVERSAL::can(dbh, 'sprintProfile')
                  ? encode_entities(dbh->sprintProfile())
                  : 'DBIx::Profile missing sprintProfile method;'.
                    'unpatched or too old?'                        ).
            #"\n\n". &sprintAutoProfile().  '</PRE>'.
            "\n\n".                         '</PRE>'.
            '</BODY></HTML>';
          dbh->{'private_profile'} = {};
          return $page;

        } else { #normal redirect

          $m->redirect($location);
          '';

        }

      };
      
      unless ( $HTML::Mason::r->filename =~ /\/rt\/.*NoAuth/ ) { #RT
        $cgi = new CGI;
        &cgisuidsetup($cgi);
        #&cgisuidsetup($r);
        $p = popurl(2);
        $fsurl = rooturl();
      }

      sub include {
        use vars qw($m);
        $m->scomp(@_);
      }

      sub redirect {
        my( $location ) = @_;
        use vars qw($m);
        $m->clear_buffer;
        #false laziness w/above
        if ( defined(@DBIx::Profile::ISA) ) { #profiling redirect

          $m->print(
            qq!<HTML><BODY>Redirect to <A HREF="$location">$location</A>!.
            '<BR><BR><PRE>'.
              ( UNIVERSAL::can(dbh, 'sprintProfile')
                  ? encode_entities(dbh->sprintProfile())
                  : 'DBIx::Profile missing sprintProfile method;'.
                    'unpatched or too old?'                        ).
            #"\n\n". &sprintAutoProfile().  '</PRE>'.
            "\n\n".                         '</PRE>'.
            '</BODY></HTML>'
          );
          dbh->{'private_profile'} = {};

          #whew.  removing this is all that's needed to fix the annoying
          #blank-page-instead-of-profiling-redirect-when-called-from-an-include
          #bug triggered by mason 1.32
          #my $rv = $m->abort(200);

        } else { #normal redirect

          $m->redirect($location);

        }

      }

    } # end package HTML::Mason::Commands;

    ###Module::Refresh->refresh;###

    $r->content_type('text/html');
    #eorar

    my $headers = $r->headers_out;
    $headers->{'Cache-control'} = 'no-cache';
    #$r->no_cache(1);
    $headers->{'Expires'} = '0';

#    $r->send_http_header;

    #$ah->interp->remove_escape('h');

    if ( $r->filename =~ /\/rt\// ) { #RT
      #warn "processing RT file". $r->filename. "; escaping for RT\n";

      # MasonX::Request::ExtendedCompRoot
      #$ah->interp->comp_root( '/rt'. $ah->interp->comp_root() );

      $ah->interp->set_escape( h => \&RT::Interface::Web::EscapeUTF8 );

      local $SIG{__WARN__};
      local $SIG{__DIE__};

      RT::Init();

      # We don't need to handle non-text, non-xml items
      return -1 if defined( $r->content_type ) && $r->content_type !~ m!(^text/|\bxml\b)!io;

    } else {
      $ah->interp->set_escape( 'h' => sub { ${$_[0]}; } );
    }

    $ah->interp->ignore_warnings_expr('.');

    my %session;
    my $status;
    eval { $status = $ah->handle_request($r); };
#!!
#    if ( $@ ) {
#	$RT::Logger->crit($@);
#    }

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
