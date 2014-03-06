package FS::ClientAPI::Signup;

use strict;
use vars qw( $DEBUG $me );
use Data::Dumper;
use Tie::RefHash;
use Digest::SHA qw(sha512_hex);
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbdef);
use FS::CGI qw(popurl);
use FS::Msgcat qw(gettext);
use FS::Misc qw(card_types);
use FS::ClientAPI_SessionCache;
use FS::agent;
use FS::cust_main_county;
use FS::part_pkg;
use FS::svc_acct_pop;
use FS::cust_main;
use FS::cust_pkg;
use FS::svc_acct;
use FS::svc_phone;
use FS::acct_snarf;
use FS::queue;
use FS::reg_code;
use FS::payby;
use FS::banned_pay;

$DEBUG = 1;
$me = '[FS::ClientAPI::Signup]';

sub clear_cache {
  warn "$me clear_cache called\n" if $DEBUG;
  my $cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Signup',
  } );
  $cache->clear();
  return {};
}

sub signup_info {
  my $packet = shift;

  warn "$me signup_info called on $packet\n" if $DEBUG;

  my $conf = new FS::Conf;
  my $svc_x = $conf->config('signup_server-service') || 'svc_acct';

  my $cache = new FS::ClientAPI_SessionCache( {
    'namespace' => 'FS::ClientAPI::Signup',
  } );
  my $signup_info_cache = $cache->get('signup_info_cache');

  if ( $signup_info_cache ) {

    warn "$me loading cached signup info\n" if $DEBUG > 1;

  } else {

    warn "$me populating signup info cache\n" if $DEBUG > 1;

    my $agentnum2part_pkg = 
      {
        map {
          my $agent = $_;
          my $href = $agent->pkgpart_hashref;
          $agent->agentnum =>
            [
              map { { 'payby'       => [ $_->payby ],
                      'freq_pretty' => $_->freq_pretty,
                      'options'     => { $_->options },
                      %{$_->hashref}
                  } }
                grep { $_->svcpart($svc_x)
                       && ( $href->{ $_->pkgpart }
                            || ( $_->agentnum
                                 && $_->agentnum == $agent->agentnum
                               )
                          )
                     }
                  qsearch( 'part_pkg', { 'disabled' => '' } )
            ];
        } qsearch('agent', { 'disabled' => '' })
      };

    my $msgcat = { map { $_=>gettext($_) }
                       qw( passwords_dont_match invalid_card unknown_card_type
                           not_a empty_password illegal_or_empty_text )
                 };
    warn "msgcat: ". Dumper($msgcat). "\n" if $DEBUG > 2;

    my $label = { map { $_ => FS::Msgcat::_gettext($_) }
                      qw( stateid stateid_state )
                };
    warn "label: ". Dumper($label). "\n" if $DEBUG > 2;

    my @agent_fields = qw( agentnum agent );

    my @bools = qw( emailinvoiceonly security_phrase );

    my @signup_bools = qw( no_company recommend_daytime recommend_email );

    my @signup_server_scalars = qw( default_pkgpart default_svcpart default_domsvc );

    my @selfservice_textareas = qw( head body_header body_footer );

    my @selfservice_scalars = qw(
      body_bgcolor box_bgcolor
      text_color link_color vlink_color hlink_color alink_color
      font title_color title_align title_size menu_bgcolor menu_fontsize
    );

    #XXX my @selfservice_bools = qw(
    #  menu_skipblanks menu_skipheadings menu_nounderline
    #);

    #my $selfservice_binaries = qw(
    #  title_left_image title_right_image
    #  menu_top_image menu_body_image menu_bottom_image
    #);

    $signup_info_cache = {

      'cust_main_county' => [ map $_->hashref,
                                  qsearch('cust_main_county', {} )
                            ],

      'agent' => [ map { my $agent = $_;
                         +{ map { $_ => $agent->get($_) } @agent_fields }
                       }
                       qsearch('agent', { 'disabled' => '' } )
                 ],

      'part_referral' => [ map $_->hashref,
                               qsearch('part_referral', { 'disabled' => '' } )
                         ],

      'agentnum2part_pkg' => $agentnum2part_pkg,

      'svc_acct_pop' => [ map $_->hashref, qsearch('svc_acct_pop',{} ) ],

      'emailinvoiceonly' => $conf->exists('emailinvoiceonly'),

      'security_phrase' => $conf->exists('security_phrase'),

      'nomadix' => $conf->exists('signup_server-nomadix'),

      'payby' => [ $conf->config('signup_server-payby') ],

      'payby_longname' => [ map { FS::payby->longname($_) } 
                            $conf->config('signup_server-payby') ],

      'card_types' => card_types(),

      ( map { $_ => $conf->exists("signup-$_") } @signup_bools ),

      ( map { $_ => scalar($conf->config("signup_server-$_")) }
            @signup_server_scalars
      ),

      ( map { $_ => join("\n", $conf->config("selfservice-$_")) }
            @selfservice_textareas
      ),
      ( map { $_ => scalar($conf->config("selfservice-$_")) }
            @selfservice_scalars
      ),

      #( map { $_ => scalar($conf->config_binary("selfservice-$_")) }
      #      @selfservice_binaries
      #),

      'agentnum2part_pkg'  => $agentnum2part_pkg,
      'svc_acct_pop'       => [ map $_->hashref, qsearch('svc_acct_pop',{} ) ],
      'nomadix'            => $conf->exists('signup_server-nomadix'),
      'payby'              => [ $conf->config('signup_server-payby') ],
      'card_types'         => card_types(),
      'paytypes'           => [ @FS::cust_main::paytypes ],
      'cvv_enabled'        => 1,
      'require_cvv'        => $conf->exists('signup-require_cvv'),
      'stateid_enabled'    => $conf->exists('show_stateid'),
      'paystate_enabled'   => $conf->exists('show_bankstate'),
      'ship_enabled'       => 1,
      'msgcat'             => $msgcat,
      'label'              => $label,
      'statedefault'       => scalar($conf->config('statedefault')) || 'CA',
      'countrydefault'     => scalar($conf->config('countrydefault')) || 'US',
      'refnum'             => scalar($conf->config('signup_server-default_refnum')),
      'signup_service'     => $svc_x,
      'company_name'       => scalar($conf->config('company_name')),
      #per-agent?
      'logo'               => scalar($conf->config_binary('logo.png')),
      'prepaid_template_custnum' => $conf->exists('signup_server-prepaid-template-custnum'),
    };

    $cache->set('signup_info_cache', $signup_info_cache);

  }

  my $signup_info = { %$signup_info_cache };
  warn "$me signup info loaded\n" if $DEBUG > 1;
  warn Dumper($signup_info). "\n" if $DEBUG > 2;

  my @addl = qw( signup_server-classnum2 signup_server-classnum3 );

  if ( grep { $conf->exists($_) } @addl ) {
  
    $signup_info->{optional_packages} = [];

    foreach my $addl ( @addl ) {

      warn "$me adding optional package info\n" if $DEBUG > 1;

      my $classnum = $conf->config($addl) or next;

      my @pkgs = map { {
                         'freq_pretty' => $_->freq_pretty,
                         'options'     => { $_->options },
                         %{ $_->hashref }
                       };
                     }
                     qsearch( 'part_pkg', { classnum => $classnum } );

      push @{$signup_info->{optional_packages}}, \@pkgs;

      warn "$me done adding opt. package info for $classnum\n" if $DEBUG > 1;

    }

  }

  my $agentnum = $packet->{'agentnum'}
                 || $conf->config('signup_server-default_agentnum');
  $agentnum =~ /^(\d*)$/ or die "illegal agentnum";
  $agentnum = $1;

  my $session = '';
  if ( exists $packet->{'session_id'} ) {

    warn "$me loading agent session\n" if $DEBUG > 1;
    my $cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Agent',
    } );
    $session = $cache->get($packet->{'session_id'});
    if ( $session ) {
      $agentnum = $session->{'agentnum'};
    } else {
      return { 'error' => "Can't resume session" }; #better error message
    }
    warn "$me done loading agent session\n" if $DEBUG > 1;

  } elsif ( exists $packet->{'customer_session_id'} ) {

    warn "$me loading customer session\n" if $DEBUG > 1;
    my $cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::MyAccount',
    } );
    $session = $cache->get($packet->{'customer_session_id'});
    if ( $session ) {
      my $custnum = $session->{'custnum'};
      my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum });
      return { 'error' => "Can't find your customer record" } unless $cust_main;
      $agentnum = $cust_main->agentnum;
    } else {
      return { 'error' => "Can't resume session" }; #better error message
    }
    warn "$me done loading customer session\n" if $DEBUG > 1;

  }

  $signup_info->{'part_pkg'} = [];

  if ( $packet->{'reg_code'} ) {

    warn "$me setting package list via reg_code\n" if $DEBUG > 1;

    $signup_info->{'part_pkg'} = 
      [ map { { 'payby'       => [ $_->payby ],
                'freq_pretty' => $_->freq_pretty,
                'options'     => { $_->options },
                %{$_->hashref}
              };
            }
          grep { $_->svcpart($svc_x) }
          map { $_->part_pkg }
            qsearchs( 'reg_code', { 'code'     => $packet->{'reg_code'},
                                    'agentnum' => $agentnum,              } )

      ];

    $signup_info->{'error'} = 'Unknown registration code'
      unless @{ $signup_info->{'part_pkg'} };

    warn "$me done setting package list via reg_code\n" if $DEBUG > 1;

  } elsif ( $packet->{'promo_code'} ) {

    warn "$me setting package list via promo_code\n" if $DEBUG > 1;

    $signup_info->{'part_pkg'} =
      [ map { { 'payby'   => [ $_->payby ],
                'freq_pretty' => $_->freq_pretty,
                'options'     => { $_->options },
                %{$_->hashref}
            } }
          grep { $_->svcpart($svc_x) }
            qsearch( 'part_pkg', { 'promo_code' => {
                                     op=>'ILIKE',
                                     value=>$packet->{'promo_code'}
                                   },
                                   'disabled'   => '',                  } )
      ];

    $signup_info->{'error'} = 'Unknown promotional code'
      unless @{ $signup_info->{'part_pkg'} };

    warn "$me done setting package list via promo_code\n" if $DEBUG > 1;
  }

  if ( $agentnum ) {

    warn "$me setting agent-specific payment flag\n" if $DEBUG > 1;
    my $agent = qsearchs('agent', { 'agentnum' => $agentnum } )
      or return { 'error' => "Self-service agent #$agentnum does not exist" };
    warn "$me has agent $agent\n" if $DEBUG > 1;
    my @paybys = @{ $signup_info->{'payby'} };
    $signup_info->{'hide_payment_fields'} = [];

    my $gatewaynum = $conf->config('selfservice-payment_gateway');
    my $force_gateway;
    if ( $gatewaynum ) {
      $force_gateway = qsearchs('payment_gateway', { gatewaynum => $gatewaynum });
      warn "using forced gateway #$gatewaynum - " .
        $force_gateway->gateway_username . '@' . $force_gateway->gateway_module
        if $DEBUG > 1;
      die "configured gatewaynum $gatewaynum not found!" if !$force_gateway;
    }
    foreach my $payby (@paybys) {
      warn "$me checking $payby payment fields\n" if $DEBUG > 1;
      my $hide = 0;
      if ( FS::payby->realtime($payby) ) {
        my $gateway = $force_gateway || 
          $agent->payment_gateway( 'method'  => FS::payby->payby2bop($payby),
                                   'nofatal' => 1,
                                 );
        if ( $gateway && $gateway->gateway_namespace
                    eq 'Business::OnlineThirdPartyPayment'
           ) {
          warn "$me hiding $payby payment fields\n" if $DEBUG > 1;
          $hide = 1;
        }
      }
      push @{$signup_info->{'hide_payment_fields'}}, $hide;
    } # foreach $payby
    warn "$me done setting agent-specific payment flag\n" if $DEBUG > 1;

    warn "$me setting agent-specific package list\n" if $DEBUG > 1;
    $signup_info->{'part_pkg'} = $signup_info->{'agentnum2part_pkg'}{$agentnum}
      unless @{ $signup_info->{'part_pkg'} };
    warn "$me done setting agent-specific package list\n" if $DEBUG > 1;

    warn "$me setting agent-specific adv. source list\n" if $DEBUG > 1;
    $signup_info->{'part_referral'} =
      [
        map { $_->hashref }
          qsearch( {
                     'table'     => 'part_referral',
                     'hashref'   => { 'disabled' => '' },
                     'extra_sql' => "AND (    agentnum = $agentnum  ".
                                    "      OR agentnum IS NULL    ) ",
                   },
                 )
      ];
    warn "$me done setting agent-specific adv. source list\n" if $DEBUG > 1;

    $signup_info->{'agent_name'} = $agent->agent;

    $signup_info->{'company_name'} = $conf->config('company_name', $agentnum);

    #some of the above could probably be cached, too

    my $signup_info_cache_agent = $cache->get("signup_info_cache_agent$agentnum");

    if ( $signup_info_cache_agent ) {

      warn "$me loading cached signup info for agentnum $agentnum\n"
        if $DEBUG > 1;

    } else {

      warn "$me populating signup info cache for agentnum $agentnum\n"
        if $DEBUG > 1;

      $signup_info_cache_agent = {
        #( map { $_ => scalar( $conf->config($_, $agentnum) ) }
        #  qw( company_name ) ),
        ( map { $_ => scalar( $conf->config("selfservice-$_", $agentnum ) ) }
          qw( body_bgcolor box_bgcolor menu_bgcolor ) ),
        ( map { $_ => join("\n", $conf->config("selfservice-$_", $agentnum ) ) }
          qw( head body_header body_footer ) ),
        ( map { $_ => join("\n", $conf->config("signup_server-$_", $agentnum ) ) }
          qw( terms_of_service ) ),

        ( map { $_ => scalar($conf->exists($_, $agentnum)) } 
          qw(cust_main-require_phone agent-ship_address) ),
      };

      if ( $signup_info_cache_agent->{'agent-ship_address'} 
           && $agent->agent_cust_main ) {

        my $cust_main = $agent->agent_cust_main;
        my $location = $cust_main->ship_location;
        $signup_info_cache_agent->{"ship_$_"} = $location->get($_)
          foreach qw( address1 city county state zip country );

      }

      $cache->set("signup_info_cache_agent$agentnum", $signup_info_cache_agent);

    }

    $signup_info->{$_} = $signup_info_cache_agent->{$_}
      foreach keys %$signup_info_cache_agent;

  }
  # else {
  # delete $signup_info->{'part_pkg'};
  #}

  warn "$me sorting package list\n" if $DEBUG > 1;
  $signup_info->{'part_pkg'} = [ sort { $a->{pkg} cmp $b->{pkg} }  # case?
                                      @{ $signup_info->{'part_pkg'} }
                               ];
  warn "$me done sorting package list\n" if $DEBUG > 1;

  if ( exists $packet->{'session_id'} ) {
    my $agent_signup_info = { %$signup_info };
    delete $agent_signup_info->{agentnum2part_pkg};
    $agent_signup_info->{'agent'} = $session->{'agent'};
    return $agent_signup_info;
  } 
  elsif ( exists $packet->{'keys'} ) {
    my @keys = @{ $packet->{'keys'} };
    return { map { $_ => $signup_info->{$_} } @keys };
  }
  else {
    return $signup_info;
  }

}

sub domain_select_hash {
  my $packet = shift;

  my $response = {};

  if ($packet->{pkgpart}) {
    my $part_pkg = qsearchs('part_pkg' => { 'pkgpart' => $packet->{pkgpart} } );
    #$packet->{svcpart} = $part_pkg->svcpart('svc_acct')
    $packet->{svcpart} = $part_pkg->svcpart
      if $part_pkg;
  }

  if ($packet->{svcpart}) {
    my $part_svc = qsearchs('part_svc' => { 'svcpart' => $packet->{svcpart} } );
    $response->{'domsvc'} = $part_svc->part_svc_column('domsvc')->columnvalue
      if ($part_svc && $part_svc->part_svc_column('domsvc')->columnflag  eq 'D');
  }

  $response->{'domains'}
    = { domain_select_hash FS::svc_acct( map { $_ => $packet->{$_} }
                                                 qw(svcpart pkgnum)
                                       ) };

  $response;
}

sub new_customer {
  my $packet = shift;

  my $conf = new FS::Conf;
  my $svc_x = $conf->config('signup_server-service') || 'svc_acct';

  if ( $svc_x eq 'svc_acct' ) {
  
    #things that aren't necessary in base class, but are for signup server
      #return "Passwords don't match"
      #  if $hashref->{'_password'} ne $hashref->{'_password2'}
    return { 'error' => gettext('empty_password') }
      unless length($packet->{'_password'});
    # a bit inefficient for large numbers of pops
    return { 'error' => gettext('no_access_number_selected') }
      unless $packet->{'popnum'} || !scalar(qsearch('svc_acct_pop',{} ));

  }
  elsif ( $svc_x eq 'svc_pbx' ) {
    #possibly some validation will be needed
  }

  my $agentnum;
  if ( exists $packet->{'session_id'} ) {
    my $cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Agent',
    } );
    my $session = $cache->get($packet->{'session_id'});
    if ( $session ) {
      $agentnum = $session->{'agentnum'};
    } else {
      return { 'error' => "Can't resume session" }; #better error message
    }
  } else {
    $agentnum = $packet->{agentnum}
                || $conf->config('signup_server-default_agentnum');
  }

  my ($bill_hash, $ship_hash);
  foreach my $f (FS::cust_main->location_fields) {
    # avoid having to change this in front-end code
    $bill_hash->{$f} = $packet->{"bill_$f"} || $packet->{$f};
    $ship_hash->{$f} = $packet->{"ship_$f"};
  }

  #shares some stuff with htdocs/edit/process/cust_main.cgi... take any
  # common that are still here and library them.
  my $template_custnum = $conf->config('signup_server-prepaid-template-custnum');
  my $cust_main;
  if ( $template_custnum && $packet->{prepaid_shortform} ) {

    my $template_cust = qsearchs('cust_main', { 'custnum' => $template_custnum } );
    return { 'error' => 'Configuration error' } unless $template_cust;
    $cust_main = new FS::cust_main ( {
      'agentnum'      => $agentnum,
      'refnum'        => $packet->{refnum}
                         || $conf->config('signup_server-default_refnum'),

      ( map { $_ => $template_cust->$_ } qw( 
              last first company daytime night fax mobile
            )
      ),

      ( map { $_ => $packet->{$_} } qw(
              ss stateid stateid_state

              payby
              payinfo paycvv paydate payname paystate paytype
              paystart_month paystart_year payissue
              payip

              referral_custnum comments
            )
      ),

    } );

    $bill_hash = { $template_cust->bill_location->location_hash };
    $ship_hash = { $template_cust->ship_location->location_hash };

  } else {

    $cust_main = new FS::cust_main ( {
      #'custnum'          => '',
      'agentnum'      => $agentnum,
      'refnum'        => $packet->{refnum}
                         || $conf->config('signup_server-default_refnum'),

      map { $_ => $packet->{$_} } qw(
        last first ss company 
        daytime night fax mobile
        stateid stateid_state
        payby
        payinfo paycvv paydate payname paystate paytype
        paystart_month paystart_year payissue
        payip
        override_ban_warn
        referral_custnum comments
      ),

    } );
  }

  my $bill_location = FS::cust_location->new($bill_hash);
  my $ship_location;
  my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  if ( $conf->exists('agent-ship_address', $agentnum) 
    && $agent->agent_custnum ) {

    my $agent_cust_main = $agent->agent_cust_main;
    my $prefix = length($agent_cust_main->ship_last) ? 'ship_' : '';
    $ship_location = FS::cust_location->new({ 
        $agent_cust_main->ship_location->location_hash
    });

  }
  # we don't have an equivalent of the "same" checkbox in selfservice
  # so is there a ship address, and if so, is it different from the billing 
  # address?
  elsif ( length($ship_hash->{address1}) > 0 and
          grep { $bill_hash->{$_} ne $ship_hash->{$_} } keys(%$ship_hash)
         ) {

    $ship_location = FS::cust_location->new( $ship_hash );
  
  }
  else {
    $ship_location = $bill_location;
  }

  $cust_main->set('bill_location' => $bill_location);
  $cust_main->set('ship_location' => $ship_location);

  return { 'error' => "Illegal payment type" }
    unless grep { $_ eq $packet->{'payby'} }
                $conf->config('signup_server-payby');

  if (FS::payby->realtime($packet->{payby})
    and not $conf->exists('signup_server-third_party_as_card')) {
    my $payby = $packet->{payby};

    my $agent = qsearchs('agent', { 'agentnum' => $agentnum });
    return { 'error' => "Unknown reseller" }
      unless $agent;

    my $gw;
    my $gatewaynum = $conf->config('selfservice-payment_gateway');
    if ( $gatewaynum ) {
      $gw = qsearchs('payment_gateway', { gatewaynum => $gatewaynum });
      die "configured gatewaynum $gatewaynum not found!" if !$gw;
    }
    else {
      $gw = $agent->payment_gateway( 'method'  => FS::payby->payby2bop($payby),
                                     'nofatal' => 1,
                                    );
    }

    $cust_main->payby('BILL')   # MCRD better?
      if $gw && $gw->gateway_namespace eq 'Business::OnlineThirdPartyPayment';
  }

  return { 'error' => "CVV2 is required" }
    if $cust_main->payby =~ /^(CARD|DCRD)$/
    && ! $cust_main->paycvv
    && $conf->exists('signup-require_cvv');

  $cust_main->payinfo($cust_main->daytime)
    if $cust_main->payby eq 'LECB' && ! $cust_main->payinfo;

  my @invoicing_list = $packet->{'invoicing_list'}
                         ? split( /\s*\,\s*/, $packet->{'invoicing_list'} )
                         : ();

  $packet->{'pkgpart'} =~ /^(\d+)$/ or '' =~ /^()$/;
  my $pkgpart = $1;
  return { 'error' => 'Please select a package' } unless $pkgpart; #msgcat

  my $part_pkg =
    qsearchs( 'part_pkg', { 'pkgpart' => $pkgpart } )
      or return { 'error' => "WARNING: unknown pkgpart: $pkgpart" };
  my $svcpart = $part_pkg->svcpart($svc_x);

  my $reg_code = '';
  if ( $packet->{'reg_code'} ) {
    $reg_code = qsearchs( 'reg_code', { 'code'     => $packet->{'reg_code'},
                                        'agentnum' => $agentnum,             } )
      or return { 'error' => 'Unknown registration code' };
  }

  my $cust_pkg = new FS::cust_pkg ( {
    #later#'custnum' => $custnum,
    'pkgpart'    => $packet->{'pkgpart'},
    'promo_code' => $packet->{'promo_code'},
    'reg_code'   => $packet->{'reg_code'},
  } );
  #my $error = $cust_pkg->check;
  #return { 'error' => $error } if $error;

  #should be all auto-magic and shit
  my @svc = ();
  if ( $svc_x eq 'svc_acct' ) {

    my $svc = new FS::svc_acct {
      'svcpart'   => $svcpart,
      map { $_ => $packet->{$_} }
        qw( username _password sec_phrase popnum domsvc ),
    };

    my @acct_snarf;
    my $snarfnum = 1;
    while (    exists($packet->{"snarf_machine$snarfnum"})
            && length($packet->{"snarf_machine$snarfnum"}) ) {
      my $acct_snarf = new FS::acct_snarf ( {
        'machine'   => $packet->{"snarf_machine$snarfnum"},
        'protocol'  => $packet->{"snarf_protocol$snarfnum"},
        'username'  => $packet->{"snarf_username$snarfnum"},
        '_password' => $packet->{"snarf_password$snarfnum"},
      } );
      $snarfnum++;
      push @acct_snarf, $acct_snarf;
    }
    $svc->child_objects( \@acct_snarf );
    push @svc, $svc;

  } elsif ( $svc_x eq 'svc_phone' ) {

    push @svc, new FS::svc_phone ( {
      'svcpart' => $svcpart,
       map { $_ => $packet->{$_} }
         qw( countrycode phonenum sip_password pin ),
    } );

  } elsif ( $svc_x eq 'svc_pbx' ) {

    push @svc, new FS::svc_pbx ( {
        'svcpart' => $svcpart,
        map { $_ => $packet->{$_} } 
          qw( id title ),
        } );
  
  } else {
    die "unknown signup service $svc_x";
  }

  if ($packet->{'mac_addr'} && $conf->exists('signup_server-mac_addr_svcparts'))
  {

    my %mac_addr_svcparts = map { $_ => 1 }
                            $conf->config('signup_server-mac_addr_svcparts');
    my @pkg_svc = grep { $_->quantity && $mac_addr_svcparts{$_->svcpart} }
                  $cust_pkg->part_pkg->pkg_svc;

    return { 'error' => 'No service defined to assign mac address' }
      unless @pkg_svc;

    my $svc = new FS::svc_acct {
      'svcpart'   => $pkg_svc[0]->svcpart, #multiple matches? alas..
      'username'  => $packet->{'mac_addr'},
      '_password' => '', #blank as requested (set passwordmin to 0)
    };

    push @svc, $svc;

  }

  foreach my $svc ( @svc ) {
    my $y = $svc->setdefault; # arguably should be in new method
    return { 'error' => $y } if $y && !ref($y);
    #$error = $svc->check;
    #return { 'error' => $error } if $error;
  }

  #setup a job dependancy to delay provisioning
  my $placeholder = new FS::queue ( {
    'job'    => 'FS::ClientAPI::Signup::__placeholder',
    'status' => 'locked',
  } );
  my $error = $placeholder->insert;
  return { 'error' => $error } if $error;

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => \@svc );
  #msgcat
  $error = $cust_main->insert(
    \%hash,
    \@invoicing_list,
    'depend_jobnum' => $placeholder->jobnum,
  );
  if ( $error ) {
    my $perror = $placeholder->delete;
    $error .= " (Additionally, error removing placeholder: $perror)" if $perror;
    return { 'error' => $error };
  }

  if ( $conf->exists('signup_server-realtime') ) {

    #warn "$me Billing customer...\n" if $Debug;

    my $bill_error = $cust_main->bill( 'depend_jobnum'=>$placeholder->jobnum );
    #warn "$me error billing new customer: $bill_error"
    #  if $bill_error;

    $bill_error = $cust_main->apply_payments_and_credits;
    #warn "$me error applying payments and credits for".
    #     " new customer: $bill_error"
    #  if $bill_error;

    unless ( $packet->{payby} eq 'PREPAY' ) {
      $bill_error = $cust_main->realtime_collect(
         method        => FS::payby->payby2bop( $packet->{payby} ),
         depend_jobnum => $placeholder->jobnum,
         selfservice   => 1,
      );
      #warn "$me error collecting from new customer: $bill_error"
      #  if $bill_error;
    }

    if ($bill_error && ref($bill_error) eq 'HASH') {
      return { 'error' => '_collect',
               ( map { $_ => $bill_error->{$_} }
                 qw(popup_url reference collectitems)
               ),
               amount => $cust_main->balance,
             };
    }

    $bill_error = $cust_main->apply_payments_and_credits;
    #warn "$me error applying payments and credits for".
    #     " new customer: $bill_error"
    #  if $bill_error;

    if ( $cust_main->balance > 0 ) {

      #this makes sense.  credit is "un-doing" the invoice
      $cust_main->credit( $cust_main->balance, 'signup server decline',
                          'reason_type' => $conf->config('signup_credit_type'),
                        );
      $cust_main->apply_credits;

      #should check list for errors...
      #$cust_main->suspend;
      local $FS::svc_Common::noexport_hack = 1;
      $cust_main->cancel('quiet'=>1);

      my $perror = $placeholder->depended_delete;
      warn "error removing provisioning jobs after decline: $perror" if $perror;
      unless ( $perror ) {
        $perror = $placeholder->delete;
        warn "error removing placeholder after decline: $perror" if $perror;
      }

      return { 'error' => '_decline' };
    }

  }

  if ( $reg_code ) {
    $error = $reg_code->delete;
    return { 'error' => $error } if $error;
  }

  $error = $placeholder->delete;
  return { 'error' => $error } if $error;

  if ( $conf->exists('signup-duplicate_cc-warn_hours') ) {
    my $hours = $conf->config('signup-duplicate_cc-warn_hours');
    my $ban = new FS::banned_pay $cust_main->_new_banned_pay_hashref;
    $ban->end_date( int( time + $hours*3600 ) );
    $ban->bantype('warn');
    $ban->reason('signup-duplicate_cc-warn_hours');
    $error = $ban->insert;
    warn "WARNING: error inserting temporary banned_pay for ".
         " signup-duplicate_cc-warn_hours (proceeding anyway): $error"
      if $error;
  }

  my %return = ( 'error'          => '',
                 'signup_service' => $svc_x,
                 'custnum'        => $cust_main->custnum,
               );

  if ( $svc[0] ) {

    $return{'svcnum'} = $svc[0]->svcnum;

    if ( $svc_x eq 'svc_acct' ) {
      $return{$_} = $svc[0]->$_() for qw( username _password );
    } elsif ( $svc_x eq 'svc_phone' ) {
      $return{$_} = $svc[0]->$_() for qw(countrycode phonenum sip_password pin);
    } elsif ( $svc_x eq 'svc_pbx' ) {
      #$return{$_} = $svc[0]->$_() for qw( ) #nothing yet
     } else {
      return {'error' => "configuration error: unknown signup service $svc_x"};
      #die "unknown signup service $svc_x";
      # return an error that's visible to someone somewhere
    }

  }

  return \%return;

}

#false laziness w/ above
# fresh restart to support "free account" portals with 3.x/4.x-style
#  addressless accounts
# and a contact (for self-service login)
sub new_customer_minimal {
  my $packet = shift;

  my $conf = new FS::Conf;
  my $svc_x = $conf->config('signup_server-service') || 'svc_acct';

  if ( $svc_x eq 'svc_acct' ) {
  
    #things that aren't necessary in base class, but are for signup server
      #return "Passwords don't match"
      #  if $hashref->{'_password'} ne $hashref->{'_password2'}
    return { 'error' => gettext('empty_password') }
      unless length($packet->{'_password'});
    # a bit inefficient for large numbers of pops
    return { 'error' => gettext('no_access_number_selected') }
      unless $packet->{'popnum'} || !scalar(qsearch('svc_acct_pop',{} ));

  }
  elsif ( $svc_x eq 'svc_pbx' ) {
    #possibly some validation will be needed
  }

  my $agentnum;
  if ( exists $packet->{'session_id'} ) {
    my $cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Agent',
    } );
    my $session = $cache->get($packet->{'session_id'});
    if ( $session ) {
      $agentnum = $session->{'agentnum'};
    } else {
      return { 'error' => "Can't resume session" }; #better error message
    }
  } else {
    $agentnum = $packet->{agentnum}
                || $conf->config('signup_server-default_agentnum');
  }

  #shares some stuff with htdocs/edit/process/cust_main.cgi... take any
  # common that are still here and library them.

  my $cust_main = new FS::cust_main ( {
      #'custnum'          => '',
      'agentnum'      => $agentnum,
      'refnum'        => $packet->{refnum}
                         || $conf->config('signup_server-default_refnum'),
      'payby'         => 'BILL',

      map { $_ => $packet->{$_} } qw(
        last first ss company 
        daytime night fax mobile
      ),

  } );

  my @invoicing_list = $packet->{'invoicing_list'}
                         ? split( /\s*\,\s*/, $packet->{'invoicing_list'} )
                         : ();

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash', ();
  my @svc = ();

  $packet->{'pkgpart'} =~ /^(\d+)$/ or '' =~ /^()$/;
  my $pkgpart = $1;

  if ( $pkgpart ) {

    my $part_pkg =
      qsearchs( 'part_pkg', { 'pkgpart' => $pkgpart } )
        or return { 'error' => "WARNING: unknown pkgpart: $pkgpart" };
    my $svcpart = $part_pkg->svcpart($svc_x);

    my $cust_pkg = new FS::cust_pkg ( {
      #later#'custnum' => $custnum,
      'pkgpart'    => $packet->{'pkgpart'},
    } );
    #my $error = $cust_pkg->check;
    #return { 'error' => $error } if $error;

    #should be all auto-magic and shit
    if ( $svc_x eq 'svc_acct' ) {

      my $svc = new FS::svc_acct {
        'svcpart'   => $svcpart,
        map { $_ => $packet->{$_} }
          qw( username _password sec_phrase popnum domsvc ),
      };

      push @svc, $svc;

    } elsif ( $svc_x eq 'svc_phone' ) {

      push @svc, new FS::svc_phone ( {
        'svcpart' => $svcpart,
         map { $_ => $packet->{$_} }
           qw( countrycode phonenum sip_password pin ),
      } );

    } elsif ( $svc_x eq 'svc_pbx' ) {

      push @svc, new FS::svc_pbx ( {
          'svcpart' => $svcpart,
          map { $_ => $packet->{$_} } 
            qw( id title ),
          } );
    
    } else {
      die "unknown signup service $svc_x";
    }

    foreach my $svc ( @svc ) {
      my $y = $svc->setdefault; # arguably should be in new method
      return { 'error' => $y } if $y && !ref($y);
      #$error = $svc->check;
      #return { 'error' => $error } if $error;
    }

    use Tie::RefHash;
    tie my %hash, 'Tie::RefHash';
    $hash{ $cust_pkg } = \@svc;

  }

  my %opt = ();
  if ( $invoicing_list[0] && $packet->{'_password'} ) {
    $opt{'contact'} = [
      new FS::contact { 'first'        => $cust_main->first,
                        'last'         => $cust_main->get('last'),
                        '_password'    => $packet->{'_password'},
                        'emailaddress' => $invoicing_list[0],
                        'selfservice_access' => 'Y',
                      }
    ];
  }

  my $error = $cust_main->insert(
    \%hash,
    \@invoicing_list,
    %opt,
  );
  return { 'error' => $error } if $error;

  my $session = { 'custnum' => $cust_main->custnum };

  my $session_id;
  do {
    $session_id = sha1_hex(time(). {}. rand(). $$)
  } until ( ! defined _myaccount_cache->get($session_id) ); #just in case

  _cache->set( $session_id, $session, '1 hour' ); # 1 hour?

  my %return = ( 'error'          => '',
                 'signup_service' => $svc_x,
                 'custnum'        => $cust_main->custnum,
                 'session_id'     => $session_id,
               );

  if ( $svc[0] ) {

    $return{'svcnum'} = $svc[0]->svcnum;

    if ( $svc_x eq 'svc_acct' ) {
      $return{$_} = $svc[0]->$_() for qw( username _password );
    } elsif ( $svc_x eq 'svc_phone' ) {
      $return{$_} = $svc[0]->$_() for qw(countrycode phonenum sip_password pin);
    } elsif ( $svc_x eq 'svc_pbx' ) {
      #$return{$_} = $svc[0]->$_() for qw( ) #nothing yet
     } else {
      return {'error' => "configuration error: unknown signup service $svc_x"};
      #die "unknown signup service $svc_x";
      # return an error that's visible to someone somewhere
    }

  }

  return \%return;

}

use vars qw( $myaccount_cache );
sub _myaccount_cache {
  $myaccount_cache ||= new FS::ClientAPI_SessionCache( {
                         'namespace' => 'FS::ClientAPI::MyAccount',
                       } );
}

sub capture_payment {
  my $packet = shift;

  warn "$me capture_payment called on $packet\n" if $DEBUG;

  ###
  # identify processor/gateway from called back URL
  ###

  my $conf = new FS::Conf;

  my $payment_gateway;
  if ( my $gwnum = $conf->config('selfservice-payment_gateway') ) {
    $payment_gateway = qsearchs('payment_gateway', { 'gatewaynum' => $gwnum })
      or die "configured gatewaynum $gwnum not found!";
  }
  else {
    my $url = $packet->{url};

    $payment_gateway = qsearchs('payment_gateway', 
        { 'gateway_callback_url' => popurl(0, $url) } 
      );
    if (!$payment_gateway) { 

      my ( $processor, $login, $password, $action, @bop_options ) =
        $conf->config('business-onlinepayment');
      $action ||= 'normal authorization';
      pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
      die "No real-time processor is enabled - ".
          "did you set the business-onlinepayment configuration value?\n"
        unless $processor;

      $payment_gateway = new FS::payment_gateway( {
        gateway_namespace => $conf->config('business-onlinepayment-namespace'),
        gateway_module    => $processor,
        gateway_username  => $login,
        gateway_password  => $password,
        gateway_action    => $action,
        options   => [ ( @bop_options ) ],
      });
    }
  }
 
  die "No real-time third party processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n*"
    unless $payment_gateway->gateway_namespace eq 'Business::OnlineThirdPartyPayment';

  ###
  # locate pending transaction
  ###

  eval "use Business::OnlineThirdPartyPayment";
  die $@ if $@;

  my $transaction =
    new Business::OnlineThirdPartyPayment( $payment_gateway->gateway_module,
                                           @{ [ $payment_gateway->options ] },
                                         );

  my $paypendingnum = $transaction->reference($packet->{data});

  my $cust_pay_pending =
    qsearchs('cust_pay_pending', { paypendingnum => $paypendingnum } );

  unless ($cust_pay_pending) {
    my $bill_error = "No payment is being processed with id $paypendingnum".
                     "; Transaction aborted.";
    return { error => '_decline', bill_error => $bill_error };
  }

  if ($cust_pay_pending->status ne 'thirdparty') {
    my $bill_error = "Payment with id $paypendingnum is not thirdparty, but ".
                     $cust_pay_pending->status.  "; Transaction aborted.";
    return { error => '_decline', bill_error => $bill_error };
  }

  my $cust_main = $cust_pay_pending->cust_main;
  if ( $packet->{cancel} ) {
    # the user has chosen not to make this payment
    # (probably should be a separate API call, but I don't want to duplicate
    # all of the above...which should eventually go away)
    my $error = $cust_pay_pending->delete;
    # don't show any errors related to this; they're not meaningful
    warn "error canceling pending payment $paypendingnum: $error\n" if $error;
    return { 'error'      => '_cancel',
             'session_id' => $cust_pay_pending->session_id };
  } else {
    # create the payment
    my $bill_error =
      $cust_main->realtime_botpp_capture( $cust_pay_pending, 
        %{$packet->{data}},
        apply => 1,
    );

    return { 'error'      => ( $bill_error->{bill_error} ? '_decline' : '' ),
             %$bill_error,
           };
  }

}

1;
