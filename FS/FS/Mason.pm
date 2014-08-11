package FS::Mason;

use strict;
use vars qw( @ISA @EXPORT_OK $addl_handler_use );
use Exporter;
use Carp;
use File::Slurp qw( slurp );
use HTML::Mason 1.27; #http://www.masonhq.com/?ApacheModPerl2Redirect
use HTML::Mason::Interp;
use HTML::Mason::Compiler::ToObject;

@ISA = qw( Exporter );
@EXPORT_OK = qw( mason_interps );

=head1 NAME

FS::Mason - Initialize the Mason environment

=head1 SYNOPSIS

  use FS::Mason qw( mason_interps );

  my( $fs_interp, $rt_interp ) = mason_interps('apache');

  #OR

  my( $fs_interp, $rt_interp ) = mason_interps('standalone'); #XXX name?

=head1 DESCRIPTION

Initializes the Mason environment, loads all Freeside and RT libraries, etc.

=cut

$addl_handler_use = '';
my $addl_handler_use_file = '%%%FREESIDE_CONF%%%/addl_handler_use.pl';
if ( -e $addl_handler_use_file ) {
  $addl_handler_use = slurp( $addl_handler_use_file );
}

# List of modules that you want to use from components (see Admin
# manual for details)
{
  package HTML::Mason::Commands;

  use strict;
  use vars qw( %session );
  use CGI 3.29 qw(-private_tempfiles); #3.29 to fix RT attachment problems

  #breaks quick payment entry
  #http://rt.cpan.org/Public/Bug/Display.html?id=37365
  die "CGI.pm v3.38 is broken, use any other version >= 3.29".
      " (Debian 5.0?  aptitude remove libcgi-pm-perl)"
    if $CGI::VERSION == 3.38;

  #use CGI::Carp qw(fatalsToBrowser);
  use CGI::Cookie;
  use List::Util qw( max min sum );
  use List::MoreUtils qw( first_index uniq );
  use Scalar::Util qw( blessed );
  use Data::Dumper;
  use Date::Format;
  use Time::Local;
  use Time::HiRes;
  use Time::Duration;
  use DateTime;
  use DateTime::Format::Strptime;
  use FS::Misc::DateTime qw( parse_datetime );
  use FS::Misc::Geo qw( get_district );
  use Lingua::EN::Inflect qw(PL);
  Lingua::EN::Inflect::classical names=>0; #Categorys
  use Tie::IxHash;
  use URI;
  use URI::Escape 3.31;
  use HTML::Entities;
  use HTML::TreeBuilder;
  use HTML::TableExtract qw(tree);
  use HTML::FormatText;
  use HTML::Defang;
  use JSON::XS;
  use MIME::Base64;
  use IO::Handle;
  use IO::File;
  use IO::Scalar;
  use IO::String;
  use File::Slurp qw( slurp );
  #not actually using this yet anyway...# use IPC::Run3 0.036;
  use Net::Whois::Raw qw(whois);
  if ( $] < 5.006 ) {
    eval "use Net::Whois::Raw 0.32 qw(whois)";
    die $@ if $@;
  }
  use Text::CSV_XS;
  use Spreadsheet::WriteExcel;
  use Spreadsheet::WriteExcel::Utility;
  use OLE::Storage_Lite;
  use Excel::Writer::XLSX;
  #use Excel::Writer::XLSX::Utility; #redundant with above

  use Business::CreditCard 0.30; #for mask-aware cardtype()
  use NetAddr::IP;
  use Net::MAC::Vendor;
  use Net::Ping;
  use Net::Ping::External;
  #if CPAN #7815 ever gets fixed# if ( $Net::Ping::External::VERSION <= 0.12 )
  {
    no warnings 'redefine';
    eval 'sub Net::Ping::External::_ping_linux { 
            my %args = @_;
            my $command = "ping -s $args{size} -c $args{count} -w $args{timeout} $args{host}";
            return Net::Ping::External::_ping_system($command, 0);
          }
         ';
    die $@ if $@;
  }
  use String::Approx qw(amatch);
  use Chart::LinesPoints;
  use Chart::Mountain;
  use Chart::Bars;
  use Color::Scheme;
  use HTML::Widgets::SelectLayers 0.07; #should go away in favor of
                                        #selectlayers.html
  use Locale::Country;
  use Locale::Currency;
  use Locale::Currency::Format;
  use Business::US::USPS::WebTools::AddressStandardization;
  use Geo::GoogleEarth::Pluggable;
  use LWP::UserAgent;
  use Storable qw( nfreeze thaw );
  use FS;
  use FS::UID qw( dbh datasrc driver_name );
  use FS::Record qw( qsearch qsearchs fields dbdef
                    str2time_sql str2time_sql_closing
                    midnight_sql
                   );
  use FS::Conf;
  use FS::CGI qw(header menubar table itable ntable idiot
                 eidiot myexit http_header);
  use FS::UI::Web qw(svc_url);
  use FS::UI::Web::small_custview qw(small_custview);
  use FS::UI::bytecount;
  use FS::UI::REST qw( rest_auth rest_uri_remain encode_rest );
  use FS::Msgcat qw(gettext geterror);
  use FS::Misc qw( send_email send_fax ocr_image
                   states_hash counties cities state_label
                 );
  use FS::Misc::eps2png qw( eps2png );
  use FS::Report::FCC_477;
  use FS::Report::Table;
  use FS::Report::Table::Monthly;
  use FS::Report::Table::Daily;
  use FS::Report::Tax;
  use FS::TicketSystem;
  use FS::NetworkMonitoringSystem;
  use FS::Tron qw( tron_lint );
  use FS::Locales;
  use FS::Maketext qw( mt emt js_mt );

  use FS::agent;
  use FS::agent_type;
  use FS::domain_record;
  use FS::cust_bill;
  use FS::cust_bill_pay;
  use FS::cust_credit;
  use FS::cust_credit_bill;
  use FS::cust_main;
  use FS::h_cust_main;
  use FS::cust_main::Search qw(smart_search);
  use FS::cust_main::Import;
  use FS::cust_main::Import_Charges;
  use FS::cust_main_county;
  use FS::cust_location;
  use FS::cust_pay;
  use FS::cust_pkg;
  use FS::cust_pkg::Import;
  use FS::part_pkg_taxclass;
  use FS::cust_pkg_reason;
  use FS::cust_refund;
  use FS::cust_credit_refund;
  use FS::cust_pay_refund;
  use FS::cust_svc;
  use FS::nas;
  use FS::part_bill_event;
  use FS::part_event;
  use FS::part_event_condition;
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
  use FS::acct_rt_transaction;
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
  use FS::export_device;
  use FS::msgcat;
  use FS::rate;
  use FS::rate_region;
  use FS::rate_prefix;
  use FS::rate_detail;
  use FS::usage_class;
  use FS::payment_gateway;
  use FS::agent_payment_gateway;
  use FS::payby;
  use FS::cdr;
  use FS::cdr_batch;
  use FS::inventory_class;
  use FS::inventory_item;
  use FS::pkg_category;
  use FS::pkg_class;
  use FS::access_user;
  use FS::access_user_pref;
  use FS::access_group;
  use FS::access_usergroup;
  use FS::access_groupagent;
  use FS::access_right;
  use FS::AccessRight;
  use FS::svc_phone;
  use FS::phone_device;
  use FS::part_device;
  use FS::reason_type;
  use FS::reason;
  use FS::cust_main_note;
  use FS::tax_class;
  use FS::cust_tax_location;
  use FS::part_pkg_taxproduct;
  use FS::part_pkg_taxoverride;
  use FS::part_pkg_taxrate;
  use FS::tax_rate;
  use FS::part_pkg_report_option;
  use FS::cust_attachment;
  use FS::h_cust_pkg;
  use FS::h_inventory_item;
  use FS::h_svc_acct;
  use FS::h_svc_broadband;
  use FS::h_svc_domain;
  #use FS::h_domain_record;
  use FS::h_svc_external;
  use FS::h_svc_forward;
  use FS::h_svc_phone;
  #use FS::h_phone_device;
  use FS::h_svc_www;
  use FS::cust_statement;
  use FS::cust_class;
  use FS::cust_category;
  use FS::prospect_main;
  use FS::contact;
  use FS::phone_type;
  use FS::svc_pbx;
  use FS::discount;
  use FS::cust_pkg_discount;
  use FS::cust_bill_pkg_discount;
  use FS::svc_mailinglist;
  use FS::cgp_rule;
  use FS::cgp_rule_condition;
  use FS::cgp_rule_action;
  use FS::bill_batch;
  use FS::cust_bill_batch;
  use FS::rate_time;
  use FS::rate_time_interval;
  use FS::msg_template;
  use FS::part_tag;
  use FS::acct_snarf;
  use FS::part_pkg_discount;
  use FS::svc_cert;
  use FS::svc_dsl;
  use FS::qual;
  use FS::qual_option;
  use FS::dsl_note;
  use FS::part_pkg_vendor;
  use FS::cust_note_class;
  use FS::svc_port;
  use FS::lata;
  use FS::did_vendor;
  use FS::did_order;
  use FS::torrus_srvderive;
  use FS::torrus_srvderive_component;
  use FS::areacode;
  use FS::svc_dish;
  use FS::h_svc_dish;
  use FS::svc_hardware;
  use FS::h_svc_hardware;
  use FS::hardware_class;
  use FS::hardware_type;
  use FS::hardware_status;
  use FS::did_order_item;
  use FS::msa;
  use FS::rate_center;
  use FS::cust_msg;
  use FS::radius_group;
  use FS::template_content;
  use FS::dsl_device;
  use FS::nas;
  use FS::nas;
  use FS::export_nas;
  use FS::legacy_cust_bill;
  use FS::rate_tier;
  use FS::rate_tier_detail;
  use FS::radius_attr;
  use FS::discount_plan;
  use FS::tower;
  use FS::tower_sector;
  use FS::sales;
  use FS::contact_class;
  use FS::part_svc_class;
  use FS::upload_target;
  use FS::quotation;
  use FS::quotation_pkg;
  use FS::quotation_pkg_discount;
  use FS::cust_bill_void;
  use FS::cust_bill_pkg_void;
  use FS::cust_bill_pkg_detail_void;
  use FS::cust_bill_pkg_display_void;
  use FS::cust_bill_pkg_tax_location_void;
  use FS::cust_bill_pkg_tax_rate_location_void;
  use FS::cust_tax_exempt_pkg_void;
  use FS::cust_bill_pkg_discount_void;
  use FS::agent_pkg_class;
  use FS::svc_export_machine;
  use FS::GeocodeCache;
  use FS::log;
  use FS::log_context;
  use FS::part_pkg_usage_class;
  use FS::cust_pkg_usage;
  use FS::part_pkg_usage_class;
  use FS::part_pkg_usage;
  use FS::cdr_cust_pkg_usage;
  use FS::part_pkg_msgcat;
  use FS::svc_cable;
  use FS::agent_currency;
  use FS::currency_exchange;
  use FS::part_pkg_currency;
  use FS::cust_payby;
  use FS::vend_main;
  use FS::vend_class;
  use FS::vend_bill;
  use FS::vend_pay;
  use FS::vend_bill_pay;
  use FS::sales_pkg_class;
  use FS::svc_alarm;
  use FS::cable_model;
  use FS::invoice_mode;
  use FS::invoice_conf;
  use FS::cable_provider;
  use FS::cust_credit_void;
  use FS::discount_class;
  use FS::alarm_system;
  use FS::alarm_type;
  use FS::alarm_station;
  use FS::addr_range;
  use FS::svc_conferencing;
  use FS::conferencing_type;
  use FS::conferencing_quality;
  use FS::svc_video;
  use FS::part_pkg_usageprice;
  use FS::cust_pkg_usageprice;
  use FS::pbx_extension;
  use FS::pbx_device;
  use FS::extension_device;
  use FS::cust_main_credit_limit;
  use FS::cust_event_fee;
  use FS::part_fee;
  use FS::cust_bill_pkg_fee;
  use FS::part_fee_msgcat;
  use FS::part_fee_usage;
  use FS::sched_item;
  use FS::sched_avail;
  use FS::export_batch;
  use FS::export_batch_item;
  use FS::part_pkg_fcc_option;
  use FS::state;
  use FS::state;
  use FS::queue_stat;
  use FS::deploy_zone;
  use FS::deploy_zone_block;
  use FS::deploy_zone_vertex;
  # Sammath Naur

  if ( $FS::Mason::addl_handler_use ) {
    eval $FS::Mason::addl_handler_use;
    die $@ if $@;
  }

  if ( %%%RT_ENABLED%%% ) {
    eval '
      use lib ( "/opt/rt3/local/lib", "/opt/rt3/lib" );
      use vars qw($Nobody $SystemUser);
      use RT;
      use RT::Util;
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

      #blah.  manually updated from RT::Interface::Web::Handler
      use RT::Interface::Web;
      use MIME::Entity;
      use Text::Wrapper;
      use Time::ParseDate;
      use Time::HiRes;
      use HTML::Scrubber;

      #blah.  not even in RT::Interface::Web::Handler, just in 
      #html/NoAuth/css/dhandler and rt-test-dependencies.  ask for it here
      #to throw a real error instead of just a mysterious unstyled RT
      use CSS::Squish 0.06;

      use RT::Interface::Web::Request;

      #another undeclared web UI dep (for ticket links graph)
      use IPC::Run::SafeHandles;

      #slow, unreliable, segfaults and is optional
      #see rt/html/Ticket/Elements/ShowTransactionAttachments
      #use Text::Quoted;

      #?#use File::Path qw( rmtree );
      #?#use File::Glob qw( bsd_glob );
      #?#use File::Spec::Unix;

    ';
    die $@ if $@;
  }

  *CGI::redirect = sub {
    my $self = shift;
    my $cookie = '';
    if ( $_[0] eq '-cookie' ) { #this isn't actually used at the moment
      (my $x, $cookie) = (shift, shift);
      $HTML::Mason::r->err_headers_out->add( 'Set-cookie' => $cookie );
    }
    my $location = shift;

    use vars qw($m);

    # false laziness w/below
    if ( @DBIx::Profile::ISA ) {

      if ( $FS::CurrentUser::CurrentUser->option('show_db_profile') ) {

        #profiling redirect

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

      } else {

        #clear db profile, but normal redirect
        dbh->{'private_profile'} = {};
        $m->redirect($location);
        '';

      }

    } else { #normal redirect

      $m->redirect($location);
      '';

    }

  };
  
  sub include {
    use vars qw($m);
    #carp #should just switch to <& &> syntax
    $m->scomp(@_);
  }

  sub errorpage {
    use vars qw($m);
    $m->comp('/elements/errorpage.html', @_);
  }

  sub errorpage_popup {
    use vars qw($m);
    $m->comp('/elements/errorpage-popup.html', @_);
  }

  sub redirect {
    my( $location ) = @_;
    use vars qw($m);
    $m->clear_buffer;
    #false laziness w/above
    if ( @DBIx::Profile::ISA ) {

      if ( $FS::CurrentUser::CurrentUser->option('show_db_profile') ) {

        #profiling redirect

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

      } else {

        #clear db profile, but normal redirect
        dbh->{'private_profile'} = {};
        $m->redirect($location);

      }

    } else { #normal redirect

      $m->redirect($location);

    }

  }

} # end package HTML::Mason::Commands;

=head1 SUBROUTINE

=over 4

=item mason_interps [ MODE [ OPTION => VALUE ... ] ]

Returns a list consisting of two HTML::Mason::Interp objects, the first for
Freeside pages, and the second for RT pages.

MODE can be 'apache' or 'standalone'.  If not specified, defaults to 'apache'.

Options and values can be passed following mode.  Currently available options
are:

I<outbuf> should be set to a scalar reference in standalone mode.

=cut

my %defang_opts = ( attribs_to_callback => ['src'], attribs_callback => sub { 1 });

sub mason_interps {
  my $mode = shift || 'apache';
  my %opt = @_;

  #my $request_class = 'HTML::Mason::Request'.
                      #( $mode eq 'apache' ? '::ApacheHandler' : '' );
  my $request_class = $mode eq 'standalone' ? 'FS::Mason::StandaloneRequest'
                                            : 'FS::Mason::Request';

  #not entirely sure it belongs here, but what the hey
  if ( %%%RT_ENABLED%%% && $mode ne 'standalone' ) {
    RT::LoadConfig();
  }

  my $fs_comp_root = '%%%FREESIDE_DOCUMENT_ROOT%%%';

  my %interp = (
    request_class        => $request_class,
    data_dir             => '%%%MASONDATA%%%',
    error_mode           => 'output',
    error_format         => 'html',
    ignore_warnings_expr => '.',
  );

  $interp{out_method} = $opt{outbuf} if $mode eq 'standalone' && $opt{outbuf};

  my $html_defang = new HTML::Defang (%defang_opts);

  #false laziness w/ FS::Maketext js_mt
  my $js_string_sub = sub {
    #${$_[0]} =~ s/(['\\\n])/'\\'.($1 eq "\n" ? 'n' : $1)/ge;
    ${$_[0]} =~ s/(['\\])/\\$1/g;
    ${$_[0]} =~ s/\r/\\r/g;
    ${$_[0]} =~ s/\n/\\n/g;
    # prevent premature termination of the script
    ${$_[0]} =~ s[</script>][<\\/script>]ig;
    ${$_[0]} = "'". ${$_[0]}. "'";
  };

  my $defang_sub = sub {
    ${$_[0]} = $html_defang->defang(${$_[0]});
  };

  my $fs_interp = new HTML::Mason::Interp (
    %interp,
    comp_root    => $fs_comp_root,
    escape_flags => { 'js_string'   => $js_string_sub,
                      'defang'      => $defang_sub,
                    },
    compiler     => HTML::Mason::Compiler::ToObject->new(
                      allow_globals        => [qw(%session)],
                    ),
  );

  my $rt_interp = new HTML::Mason::Interp (
    %interp,
    comp_root    => [
                      [ 'rt'       => '%%%FREESIDE_DOCUMENT_ROOT%%%/rt' ],
                      [ 'freeside' => '%%%FREESIDE_DOCUMENT_ROOT%%%'    ],
                    ],
    escape_flags => { 'h'         => \&RT::Interface::Web::EscapeUTF8,
                      'u'         => \&RT::Interface::Web::EscapeURI,
                      'j'         => \&RT::Interface::Web::EscapeJS,
                      'js_string' => $js_string_sub,
                    },
    compiler     => HTML::Mason::Compiler::ToObject->new(
                      default_escape_flags => 'h',
                      allow_globals        => [qw(%session $DECODED_ARGS)],
                    ),
  );

  ( $fs_interp, $rt_interp );

}

=back

=head1 BUGS

Lurking in the darkness...

=head1 SEE ALSO

L<HTML::Mason>, L<FS>, L<RT>

=cut

1;
