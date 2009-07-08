package FS::Mason;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
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
  use List::Util qw( max min );
  use Data::Dumper;
  use Date::Format;
  use Date::Parse;
  use Time::Local;
  use Time::Duration;
  use DateTime;
  use DateTime::Format::Strptime;
  use Lingua::EN::Inflect qw(PL);
  use Tie::IxHash;
  use URI;
  use URI::Escape;
  use HTML::Entities;
  use HTML::TreeBuilder;
  use HTML::FormatText;
  use JSON;
  use MIME::Base64;
  use IO::Handle;
  use IO::File;
  use IO::Scalar;
  #not actually using this yet anyway...# use IPC::Run3 0.036;
  use Net::Whois::Raw qw(whois);
  if ( $] < 5.006 ) {
    eval "use Net::Whois::Raw 0.32 qw(whois)";
    die $@ if $@;
  }
  use Text::CSV_XS;
  use Spreadsheet::WriteExcel;
  use Business::CreditCard 0.30; #for mask-aware cardtype()
  use NetAddr::IP;
  use String::Approx qw(amatch);
  use Chart::LinesPoints;
  use Chart::Mountain;
  use Color::Scheme;
  use HTML::Widgets::SelectLayers 0.07; #should go away in favor of
                                        #selectlayers.html
  use Locale::Country;
  use Business::US::USPS::WebTools::AddressStandardization;
  use FS;
  use FS::UID qw( getotaker dbh datasrc driver_name );
  use FS::Record qw( qsearch qsearchs fields dbdef
                    str2time_sql str2time_sql_closing
                   );
  use FS::Conf;
  use FS::CGI qw(header menubar table itable ntable idiot
                 eidiot myexit http_header);
  use FS::UI::Web qw(svc_url);
  use FS::UI::Web::small_custview qw(small_custview);
  use FS::UI::bytecount;
  use FS::Msgcat qw(gettext geterror);
  use FS::Misc qw( send_email send_fax states_hash counties state_label );
  use FS::Misc::eps2png qw( eps2png );
  use FS::Report::Table::Monthly;
  use FS::TicketSystem;
  use FS::Tron qw( tron_lint );

  use FS::agent;
  use FS::agent_type;
  use FS::domain_record;
  use FS::cust_bill;
  use FS::cust_bill_pay;
  use FS::cust_credit;
  use FS::cust_credit_bill;
  use FS::cust_main qw(smart_search);
  use FS::cust_main::Import;
  use FS::cust_main_county;
  use FS::cust_location;
  use FS::cust_pay;
  use FS::cust_pkg;
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
  use FS::msgcat;
  use FS::rate;
  use FS::rate_region;
  use FS::rate_prefix;
  use FS::rate_detail;
  use FS::usage_class;
  use FS::payment_gateway;
  use FS::agent_payment_gateway;
  use FS::XMLRPC;
  use FS::payby;
  use FS::cdr;
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

  if ( %%%RT_ENABLED%%% ) {
    eval '
      use lib ( "/opt/rt3/local/lib", "/opt/rt3/lib" );
      use vars qw($Nobody $SystemUser);
      use RT;
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
    if ( defined(@DBIx::Profile::ISA) ) {

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
    $m->scomp(@_);
  }

  sub errorpage {
    use vars qw($m);
    $m->comp('/elements/errorpage.html', @_);
  }

  sub redirect {
    my( $location ) = @_;
    use vars qw($m);
    $m->clear_buffer;
    #false laziness w/above
    if ( defined(@DBIx::Profile::ISA) ) {

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

=item mason_interps [ MODE ]

Returns a list consisting of two HTML::Mason::Interp objects, the first for
Freeside pages, and the second for RT pages.

#MODE can be 'apache' or 'standalone'.  If not specified, defaults to 'apache'.

=cut

sub mason_interps {
  my $mode = shift || 'apache';
  my %opt = @_;

  #my $request_class = 'HTML::Mason::Request'.
                      #( $mode eq 'apache' ? '::ApacheHandler' : '' );
  my $request_class = 'FS::Mason::Request';

  #not entirely sure it belongs here, but what the hey
  if ( %%%RT_ENABLED%%% ) {
    RT::LoadConfig();
  }

  my %interp = (
    request_class        => $request_class,
    data_dir             => '%%%MASONDATA%%%',
    error_mode           => 'output',
    error_format         => 'html',
    ignore_warnings_expr => '.',
    comp_root            => [
                              [ 'freeside'=>'%%%FREESIDE_DOCUMENT_ROOT%%%'    ],
                              [ 'rt'      =>'%%%FREESIDE_DOCUMENT_ROOT%%%/rt' ],
                            ],
  );

  $interp{out_method} = $opt{outbuf} if $mode eq 'standalone' && $opt{outbuf};

  my $fs_interp = new HTML::Mason::Interp (
    %interp,
    escape_flags => { 'js_string' => sub {
                        #${$_[0]} =~ s/(['\\\n])/'\\'.($1 eq "\n" ? 'n' : $1)/ge;
                        ${$_[0]} =~ s/(['\\])/\\$1/g;
                        ${$_[0]} =~ s/\n/\\n/g;
                        ${$_[0]} = "'". ${$_[0]}. "'";
                      }
                    },
    compiler     => HTML::Mason::Compiler::ToObject->new(
                      allow_globals        => [qw(%session)],
                    ),
  );

  my $rt_interp = new HTML::Mason::Interp (
    %interp,
    escape_flags => { 'h' => \&RT::Interface::Web::EscapeUTF8 },
    compiler     => HTML::Mason::Compiler::ToObject->new(
                      default_escape_flags => 'h',
                      allow_globals        => [qw(%session)],
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
