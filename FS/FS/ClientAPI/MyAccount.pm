package FS::ClientAPI::MyAccount;

use 5.008; #require 5.8+ for Time::Local 1.05+
use strict;
use vars qw( $cache $DEBUG $me );
use subs qw( _cache _provision );
use IO::Scalar;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Date::Format;
use Time::Duration;
use Time::Local qw(timelocal_nocheck);
use Business::CreditCard;
use HTML::Entities;
use Text::CSV_XS;
use Spreadsheet::WriteExcel;
use FS::UI::Web::small_custview qw(small_custview); #less doh
use FS::UI::Web;
use FS::UI::bytecount qw( display_bytecount );
use FS::Conf;
#use FS::UID qw(dbh);
use FS::Record qw(qsearch qsearchs dbh);
use FS::Msgcat qw(gettext);
use FS::Misc qw(card_types);
use FS::Misc::DateTime qw(parse_datetime);
use FS::TicketSystem;
use FS::ClientAPI_SessionCache;
use FS::cust_svc;
use FS::svc_acct;
use FS::svc_forward;
use FS::svc_domain;
use FS::svc_phone;
use FS::svc_external;
use FS::svc_dsl;
use FS::dsl_device;
use FS::part_svc;
use FS::cust_main;
use FS::cust_bill;
use FS::legacy_cust_bill;
use FS::cust_main_county;
use FS::cust_pkg;
use FS::payby;
use FS::acct_rt_transaction;
use FS::msg_template;

$DEBUG = 0;
$me = '[FS::ClientAPI::MyAccount]';

use vars qw( @cust_main_editable_fields );
@cust_main_editable_fields = qw(
  first last company address1 address2 city
    county state zip country
    daytime night fax mobile
  ship_first ship_last ship_company ship_address1 ship_address2 ship_city
    ship_state ship_zip ship_country
    ship_daytime ship_night ship_fax ship_mobile
  locale
  payby payinfo payname paystart_month paystart_year payissue payip
  ss paytype paystate stateid stateid_state
);

BEGIN { #preload to reduce time customer_info takes
  if ( $FS::TicketSystem::system ) {
    warn "$me: initializing ticket system\n" if $DEBUG;
    FS::TicketSystem->init();
  }
}

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::MyAccount',
             } );
}

sub skin_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  #return { 'error' => $session } if $context eq 'error';

  my $agentnum = '';
  if ( $context eq 'customer' ) {

    my $sth = dbh->prepare('SELECT agentnum FROM cust_main WHERE custnum = ?')
      or die dbh->errstr;

    $sth->execute($custnum) or die $sth->errstr;

    $agentnum = $sth->fetchrow_arrayref->[0]
      or die "no agentnum for custnum $custnum";

  #} elsif ( $context eq 'agent' ) {
  } elsif ( defined($p->{'agentnum'}) and $p->{'agentnum'} =~ /^(\d+)$/ ) {
    $agentnum = $1;
  }

  my $conf = new FS::Conf;

  #false laziness w/Signup.pm

  my $skin_info_cache_agent = _cache->get("skin_info_cache_agent$agentnum");

  if ( $skin_info_cache_agent ) {

    warn "$me loading cached skin info for agentnum $agentnum\n"
      if $DEBUG > 1;

  } else {

    warn "$me populating skin info cache for agentnum $agentnum\n"
      if $DEBUG > 1;

    $skin_info_cache_agent = {
      'agentnum' => $agentnum,
      ( map { $_ => scalar( $conf->config($_, $agentnum) ) }
        qw( company_name date_format ) ),
      ( map { $_ => scalar( $conf->config("selfservice-$_", $agentnum ) ) }
        qw( body_bgcolor box_bgcolor
            text_color link_color vlink_color hlink_color alink_color
            font title_color title_align title_size menu_bgcolor menu_fontsize
          )
      ),
      ( map { $_ => $conf->exists("selfservice-$_", $agentnum ) }
        qw( menu_skipblanks menu_skipheadings menu_nounderline )
      ),
      ( map { $_ => scalar($conf->config_binary("selfservice-$_", $agentnum)) }
        qw( title_left_image title_right_image
            menu_top_image menu_body_image menu_bottom_image
          )
      ),
      'logo' => scalar($conf->config_binary('logo.png', $agentnum )),
      ( map { $_ => join("\n", $conf->config("selfservice-$_", $agentnum ) ) }
        qw( head body_header body_footer company_address ) ),
    };

    _cache->set("skin_info_cache_agent$agentnum", $skin_info_cache_agent);

  }

  #{ %$skin_info_cache_agent };
  $skin_info_cache_agent;

}

sub login_info {
  my $p = shift;

  my $conf = new FS::Conf;

  my %info = (
    %{ skin_info($p) },
    'phone_login'  => $conf->exists('selfservice_server-phone_login'),
    'single_domain'=> scalar($conf->config('selfservice_server-single_domain')),
  );

  return \%info;

}

#false laziness w/FS::ClientAPI::passwd::passwd
sub login {
  my $p = shift;

  my $conf = new FS::Conf;

  my $svc_x = '';
  if ( $p->{'domain'} eq 'svc_phone'
       && $conf->exists('selfservice_server-phone_login') ) { 

    my $svc_phone = qsearchs( 'svc_phone', { 'phonenum' => $p->{'username'} } );
    return { error => 'Number not found.' } unless $svc_phone;

    #XXX?
    #my $pkg_svc = $svc_acct->cust_svc->pkg_svc;
    #return { error => 'Only primary user may log in.' } 
    #  if $conf->exists('selfservice_server-primary_only')
    #    && ( ! $pkg_svc || $pkg_svc->primary_svc ne 'Y' );

    return { error => 'Incorrect PIN.' }
      unless $svc_phone->check_pin($p->{'password'});

    $svc_x = $svc_phone;

  } else {

    my $svc_domain = qsearchs('svc_domain', { 'domain' => $p->{'domain'} } )
      or return { error => 'Domain '. $p->{'domain'}. ' not found' };

    my $svc_acct = qsearchs( 'svc_acct', { 'username'  => $p->{'username'},
                                           'domsvc'    => $svc_domain->svcnum, }
                           );
    return { error => 'User not found.' } unless $svc_acct;

    if($conf->exists('selfservice_server-login_svcpart')) {
	my @svcpart = $conf->config('selfservice_server-login_svcpart');
	my $svcpart = $svc_acct->cust_svc->svcpart;
	return { error => 'Invalid user.' } 
	    unless grep($_ eq $svcpart, @svcpart);
    }

    return { error => 'Incorrect password.' }
      unless $svc_acct->check_password($p->{'password'});

    $svc_x = $svc_acct;

  }

  my $session = {
    'svcnum' => $svc_x->svcnum,
  };

  my $cust_svc = $svc_x->cust_svc;
  my $cust_pkg = $cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    my $cust_main = $cust_pkg->cust_main;
    $session->{'custnum'} = $cust_main->custnum;
    if ( $conf->exists('pkg-balances') ) {
      my @cust_pkg = grep { $_->part_pkg->freq !~ /^(0|$)/ }
                          $cust_main->ncancelled_pkgs;
      $session->{'pkgnum'} = $cust_pkg->pkgnum
        if scalar(@cust_pkg) > 1;
    }
  }

  #my $pkg_svc = $svc_acct->cust_svc->pkg_svc;
  #return { error => 'Only primary user may log in.' } 
  #  if $conf->exists('selfservice_server-primary_only')
  #    && ( ! $pkg_svc || $pkg_svc->primary_svc ne 'Y' );
  my $part_pkg = $cust_pkg->part_pkg;
  return { error => 'Only primary user may log in.' }
    if $conf->exists('selfservice_server-primary_only')
       && $cust_svc->svcpart != $part_pkg->svcpart([qw( svc_acct svc_phone )]);

  my $session_id;
  do {
    $session_id = md5_hex(md5_hex(time(). {}. rand(). $$))
  } until ( ! defined _cache->get($session_id) ); #just in case

  my $timeout = $conf->config('selfservice-session_timeout') || '1 hour';
  _cache->set( $session_id, $session, $timeout );

  return { 'error'      => '',
           'session_id' => $session_id,
         };
}

sub logout {
  my $p = shift;
  if ( $p->{'session_id'} ) {
    _cache->remove($p->{'session_id'});
    return { %{ skin_info($p) }, 'error' => '' };
  } else {
    return { %{ skin_info($p) }, 'error' => "Can't resume session" }; #better error message
  }
}

sub switch_acct {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $svc_acct = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_acct' )
    or return { 'error' => "Service not found" };

  $session->{'svcnum'} = $svc_acct->svcnum;

  my $conf = new FS::Conf;
  my $timeout = $conf->config('selfservice-session_timeout') || '1 hour';
  _cache->set( $p->{'session_id'}, $session, $timeout );

  return { 'error' => '' };

}

sub payment_gateway {
  # internal use only
  # takes a cust_main and a cust_payby entry, returns the payment_gateway
  my $conf = new FS::Conf;
  my $cust_main = shift;
  my $cust_payby = shift;
  my $gatewaynum = $conf->config('selfservice-payment_gateway');
  if ( $gatewaynum ) {
    my $pg = qsearchs('payment_gateway', { gatewaynum => $gatewaynum });
    die "configured gatewaynum $gatewaynum not found!" if !$pg;
    return $pg;
  }
  else {
    return '' if ! FS::payby->realtime($cust_payby);
    my $pg = $cust_main->agent->payment_gateway(
      'method'  => FS::payby->payby2bop($cust_payby),
      'nofatal' => 1
    );
    return $pg;
  }
}

sub access_info {
  my $p = shift;

  my $conf = new FS::Conf;

  my $info = skin_info($p);

  use vars qw( $cust_paybys ); #cache for performance
  unless ( $cust_paybys ) {

    my %cust_paybys = map { $_ => 1 }
                      map { FS::payby->payby2payment($_) }
                          $conf->config('signup_server-payby');

    $cust_paybys = [ keys %cust_paybys ];

  }
  $info->{'cust_paybys'} = $cust_paybys;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  $info->{'hide_payment_fields'} = [ 
    map { 
      my $pg = payment_gateway($cust_main, $_);
      $pg && $pg->gateway_namespace eq 'Business::OnlineThirdPartyPayment';
    } @{ $info->{cust_paybys} }
  ];

  $info->{'self_suspend_reason'} = 
      $conf->config('selfservice-self_suspend_reason', $cust_main->agentnum);

  $info->{'edit_ticket_subject'} =
      $conf->exists('ticket_system-selfservice_edit_subject') && 
      $cust_main->edit_subject;

  return { %$info,
           'custnum'       => $custnum,
           'access_pkgnum' => $session->{'pkgnum'},
           'access_svcnum' => $session->{'svcnum'},
         };
}

sub customer_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my %return;

  my $conf = new FS::Conf;
  if ($conf->exists('cust_main-require_address2')) {
    $return{'require_address2'} = '1';
  }else{
    $return{'require_address2'} = '';
  }

  if ( $FS::TicketSystem::system ) {
    warn "$me customer_info: initializing ticket system\n" if $DEBUG;
    FS::TicketSystem->init();
  }
 
  if ( $custnum ) { #customer record

    my $search = { 'custnum' => $custnum };
    $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
    my $cust_main = qsearchs('cust_main', $search )
      or return { 'error' => "unknown custnum $custnum" };

    if ( $session->{'pkgnum'} ) { 
      $return{balance} = $cust_main->balance_pkgnum( $session->{'pkgnum'} );
    } else {
      $return{balance} = $cust_main->balance;
    }

    my @tickets = $cust_main->tickets;
    # unavoidable false laziness w/ httemplate/view/cust_main/tickets.html
    if ( FS::TicketSystem->selfservice_priority ) {
      my $dir = $conf->exists('ticket_system-priority_reverse') ? -1 : 1;
      $return{tickets} = [ 
        sort { 
          (
            ($a->{'_selfservice_priority'} eq '') <=>
            ($b->{'_selfservice_priority'} eq '')
          ) ||
          ( $dir * 
            ($b->{'_selfservice_priority'} <=> $a->{'_selfservice_priority'}) 
          )
        } @tickets
      ];
    }
    else {
      $return{tickets} = \@tickets;
    }

    unless ( $session->{'pkgnum'} ) {
      my @open = map {
                       {
                         invnum => $_->invnum,
                         date   => time2str("%b %o, %Y", $_->_date),
                         owed   => $_->owed,
                       };
                     } $cust_main->open_cust_bill;
      $return{open_invoices} = \@open;
    }

    $return{small_custview} =
      small_custview( $cust_main,
                      scalar($conf->config('countrydefault')),
                      ( $session->{'pkgnum'} ? 1 : 0 ), #nobalance
                    );

    $return{name} = $cust_main->first. ' '. $cust_main->get('last');
    $return{ship_name} = $cust_main->ship_first. ' '. $cust_main->get('ship_last');

    for (@cust_main_editable_fields) {
      $return{$_} = $cust_main->get($_);
    }

    if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
      $return{payinfo} = $cust_main->paymask;
      @return{'month', 'year'} = $cust_main->paydate_monthyear;
    }

    $return{'invoicing_list'} =
      join(', ', grep { $_ !~ /^(POST|FAX)$/ } $cust_main->invoicing_list );
    $return{'postal_invoicing'} =
      0 < ( grep { $_ eq 'POST' } $cust_main->invoicing_list );

    if (scalar($conf->config('support_packages'))) {
      my @support_services = ();
      foreach ($cust_main->support_services) {
        my $seconds = $_->svc_x->seconds;
        my $time_remaining = (($seconds < 0) ? '-' : '' ).
                             int(abs($seconds)/3600)."h".
                             sprintf("%02d",(abs($seconds)%3600)/60)."m";
        my $cust_pkg = $_->cust_pkg;
        my $pkgnum = '';
        my $pkg = '';
        $pkgnum = $cust_pkg->pkgnum if $cust_pkg;
        $pkg = $cust_pkg->part_pkg->pkg if $cust_pkg;
        push @support_services, { svcnum => $_->svcnum,
                                  time => $time_remaining,
                                  pkgnum => $pkgnum,
                                  pkg => $pkg,
                                };
      }
      $return{support_services} = \@support_services;
    }

    if ( $conf->config('prepayment_discounts-credit_type') ) {
      #need to eval?
      $return{discount_terms_hash} = { $cust_main->discount_terms_hash };
    }

    if ( $session->{'svcnum'} ) {
      my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $session->{'svcnum'} });
      $return{'svc_label'} = ($cust_svc->label)[1] if $cust_svc;
      $return{'svcnum'} = $session->{'svcnum'};
    }

  } elsif ( $session->{'svcnum'} ) { #no customer record

    my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $session->{'svcnum'} } )
      or die "unknown svcnum";
    $return{name} = $svc_acct->email;

  } else {

    return { 'error' => 'Expired session' }; #XXX redirect to login w/this err!

  }

  return { 'error'          => '',
           'custnum'        => $custnum,
           %return,
         };

}

sub customer_info_short {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my %return;

  my $conf = new FS::Conf;

  if ( $custnum ) { #customer record

    my $search = { 'custnum' => $custnum };
    $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
    my $cust_main = qsearchs('cust_main', $search )
      or return { 'error' => "unknown custnum $custnum" };

    $return{small_custview} =
      small_custview( $cust_main,
                      scalar($conf->config('countrydefault')),
                      1, ##nobalance
                    );

    $return{name} = $cust_main->first. ' '. $cust_main->get('last');
    $return{ship_name} = $cust_main->ship_first. ' '. $cust_main->get('ship_last');

    $return{payby} = $cust_main->payby;

    #none of these are terribly expensive if we want 'em...
    for (@cust_main_editable_fields) {
      $return{$_} = $cust_main->get($_);
    }
    
    if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
      $return{payinfo} = $cust_main->paymask;
      @return{'month', 'year'} = $cust_main->paydate_monthyear;
    }
    
    $return{'invoicing_list'} =
      join(', ', grep { $_ !~ /^(POST|FAX)$/ } $cust_main->invoicing_list );
    #$return{'postal_invoicing'} =
    #  0 < ( grep { $_ eq 'POST' } $cust_main->invoicing_list );

    if ( $session->{'svcnum'} ) {
      my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $session->{'svcnum'} });
      $return{'svc_label'} = ($cust_svc->label)[1] if $cust_svc;
      $return{'svcnum'} = $session->{'svcnum'};
    }

  } elsif ( $session->{'svcnum'} ) { #no customer record

    #uuh, not supproted yet... die?
    return { 'error' => 'customer_info_short not yet supported as agent' };

  } else {

    return { 'error' => 'Expired session' }; #XXX redirect to login w/this err!

  }

  return { 'error'          => '',
           'custnum'        => $custnum,
           %return,
         };
}

sub edit_info {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'}
    or return { 'error' => "no customer record" };

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $new = new FS::cust_main { $cust_main->hash };
  $new->set( $_ => $p->{$_} )
    foreach grep { exists $p->{$_} } @cust_main_editable_fields;

  my $payby = '';
  if (exists($p->{'payby'})) {
    $p->{'payby'} =~ /^([A-Z]{4})$/
      or return { 'error' => "illegal_payby " . $p->{'payby'} };
    $payby = $1;
  }

  if ( $payby =~ /^(CARD|DCRD)$/ ) {

    $new->paydate($p->{'year'}. '-'. $p->{'month'}. '-01');

    if ( $new->payinfo eq $cust_main->paymask ) {
      $new->payinfo($cust_main->payinfo);
    } else {
      $new->payinfo($p->{'payinfo'});
    }

    $new->set( 'payby' => $p->{'auto'} ? 'CARD' : 'DCRD' );

  } elsif ( $payby =~ /^(CHEK|DCHK)$/ ) {

    my $payinfo;
    $p->{'payinfo1'} =~ /^([\dx]+)$/
      or return { 'error' => "illegal account number ". $p->{'payinfo1'} };
    my $payinfo1 = $1;
     $p->{'payinfo2'} =~ /^([\dx\.]+)$/ # . turned on by -require-bank-branch?
      or return { 'error' => "illegal ABA/routing number ". $p->{'payinfo2'} };
    my $payinfo2 = $1;
    $payinfo = $payinfo1. '@'. $payinfo2;

    $new->payinfo( ($payinfo eq $cust_main->paymask)
                     ? $cust_main->payinfo
                     : $payinfo
                 );

    $new->set( 'payby' => $p->{'auto'} ? 'CHEK' : 'DCHK' );

  } elsif ( $payby =~ /^(BILL)$/ ) {
    #no-op
  } elsif ( $payby ) {  #notyet ready
    return { 'error' => "unknown payby $payby" };
  }

  my @invoicing_list;
  if ( exists $p->{'invoicing_list'} || exists $p->{'postal_invoicing'} ) {
    #false laziness with httemplate/edit/process/cust_main.cgi
    @invoicing_list = split( /\s*\,\s*/, $p->{'invoicing_list'} );
    push @invoicing_list, 'POST' if $p->{'postal_invoicing'};
  } else {
    @invoicing_list = $cust_main->invoicing_list;
  }

  my $error = $new->replace($cust_main, \@invoicing_list);
  return { 'error' => $error } if $error;
  #$cust_main = $new;
  
  return { 'error' => '' };
}

sub payment_info {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  ##
  #generic
  ##

  my $conf = new FS::Conf;
  use vars qw($payment_info); #cache for performance
  unless ( $payment_info ) {

    my %states = map { $_->state => 1 }
                   qsearch('cust_main_county', {
                     'country' => $conf->config('countrydefault') || 'US'
                   } );

    my %cust_paybys = map { $_ => 1 }
                      map { FS::payby->payby2payment($_) }
                          $conf->config('signup_server-payby');

    my @cust_paybys = keys %cust_paybys;

    $payment_info = {

      #list all counties/states/countries
      'cust_main_county' => 
        [ map { $_->hashref } qsearch('cust_main_county', {}) ],

      #shortcut for one-country folks
      'states' =>
        [ sort { $a cmp $b } keys %states ],

      'card_types' => card_types(),

      'paytypes' => [ @FS::cust_main::paytypes ],

      'paybys' => [ $conf->config('signup_server-payby') ],
      'cust_paybys' => \@cust_paybys,

      'stateid_label' => FS::Msgcat::_gettext('stateid'),
      'stateid_state_label' => FS::Msgcat::_gettext('stateid_state'),

      'show_ss'  => $conf->exists('show_ss'),
      'show_stateid' => $conf->exists('show_stateid'),
      'show_paystate' => $conf->exists('show_bankstate'),

      'save_unchecked' => $conf->exists('selfservice-save_unchecked'),

      'credit_card_surcharge_percentage' => $conf->config('credit-card-surcharge-percentage'),
    };

  }

  ##
  #customer-specific
  ##

  my %return = %$payment_info;

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  $return{'hide_payment_fields'} = [
    map { 
      my $pg = payment_gateway($cust_main, $_);
      $pg && $pg->gateway_namespace eq 'Business::OnlineThirdPartyPayment';
    } @{ $return{cust_paybys} }
  ];

  $return{balance} = $cust_main->balance; #XXX pkg-balances?

  $return{payname} = $cust_main->payname
                     || ( $cust_main->first. ' '. $cust_main->get('last') );

  $return{$_} = $cust_main->get($_) for qw(address1 address2 city state zip);

  $return{payby} = $cust_main->payby;
  $return{stateid_state} = $cust_main->stateid_state;

  if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
    $return{card_type} = cardtype($cust_main->payinfo);
    $return{payinfo} = $cust_main->paymask;

    @return{'month', 'year'} = $cust_main->paydate_monthyear;

  }

  if ( $cust_main->payby =~ /^(CHEK|DCHK)$/ ) {
    my ($payinfo1, $payinfo2) = split '@', $cust_main->paymask;
    $return{payinfo1} = $payinfo1;
    $return{payinfo2} = $payinfo2;
    $return{paytype}  = $cust_main->paytype;
    $return{paystate} = $cust_main->paystate;

  }

  if ( $conf->config('prepayment_discounts-credit_type') ) {
    #need to eval?
    $return{discount_terms_hash} = { $cust_main->discount_terms_hash };
  }

  #doubleclick protection
  my $_date = time;
  $return{paybatch} = "webui-MyAccount-$_date-$$-". rand() * 2**32;

  return { 'error' => '',
           %return,
         };

}

#some false laziness with httemplate/process/payment.cgi - look there for
#ACH and CVV support stuff

sub validate_payment {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  $p->{'amount'} =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or return { 'error' => gettext('illegal_amount') };
  my $amount = $1;
  return { error => 'Amount must be greater than 0' } unless $amount > 0;

  $p->{'discount_term'} =~ /^\s*(\d*)\s*$/
    or return { 'error' => gettext('illegal_discount_term'). ': '. $p->{'discount_term'} };
  my $discount_term = $1;

  $p->{'payname'} =~ /^([\w \,\.\-\']+)$/
    or return { 'error' => gettext('illegal_name'). " payname: ". $p->{'payname'} };
  my $payname = $1;

  $p->{'paybatch'} =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
    or return { 'error' => gettext('illegal_text'). " paybatch: ". $p->{'paybatch'} };
  my $paybatch = $1;

  $p->{'payby'} ||= 'CARD';
  $p->{'payby'} =~ /^([A-Z]{4})$/
    or return { 'error' => "illegal_payby " . $p->{'payby'} };
  my $payby = $1;

  #false laziness w/process/payment.cgi
  my $payinfo;
  my $paycvv = '';
  if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {
  
    $p->{'payinfo1'} =~ /^([\dx]+)$/
      or return { 'error' => "illegal account number ". $p->{'payinfo1'} };
    my $payinfo1 = $1;
     $p->{'payinfo2'} =~ /^([\dx]+)$/
      or return { 'error' => "illegal ABA/routing number ". $p->{'payinfo2'} };
    my $payinfo2 = $1;
    $payinfo = $payinfo1. '@'. $payinfo2;

    $payinfo = $cust_main->payinfo
      if $cust_main->paymask eq $payinfo;
   
  } elsif ( $payby eq 'CARD' || $payby eq 'DCRD' ) {
   
    $payinfo = $p->{'payinfo'};

    #more intelligent mathing will be needed here if you change
    #card_masking_method and don't remove existing paymasks
    $payinfo = $cust_main->payinfo
      if $cust_main->paymask eq $payinfo;

    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16}|\d{8,9})$/
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    $payinfo = $1;

    validate($payinfo)
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    return { 'error' => gettext('unknown_card_type') }
      if $payinfo !~ /^99\d{14}$/ && cardtype($payinfo) eq "Unknown";

    if ( length($p->{'paycvv'}) && $p->{'paycvv'} !~ /^\s*$/ ) {
      if ( cardtype($payinfo) eq 'American Express card' ) {
        $p->{'paycvv'} =~ /^\s*(\d{4})\s*$/
          or return { 'error' => "CVV2 (CID) for American Express cards is four digits." };
        $paycvv = $1;
      } else {
        $p->{'paycvv'} =~ /^\s*(\d{3})\s*$/
          or return { 'error' => "CVV2 (CVC2/CID) is three digits." };
        $paycvv = $1;
      }
    }
  
  } else {
    die "unknown payby $payby";
  }

  my %payby2fields = (
    'CARD' => [ qw( paystart_month paystart_year payissue payip
                    address1 address2 city state zip country    ) ],
    'CHEK' => [ qw( ss paytype paystate stateid stateid_state payip ) ],
  );

  my $card_type = '';
  $card_type = cardtype($payinfo) if $payby eq 'CARD';

  { 
    'cust_main'      => $cust_main, #XXX or just custnum??
    'amount'         => $amount,
    'payby'          => $payby,
    'payinfo'        => $payinfo,
    'paymask'        => $cust_main->mask_payinfo( $payby, $payinfo ),
    'card_type'      => $card_type,
    'paydate'        => $p->{'year'}. '-'. $p->{'month'}. '-01',
    'paydate_pretty' => $p->{'month'}. ' / '. $p->{'year'},
    'payname'        => $payname,
    'paybatch'       => $paybatch, #this doesn't actually do anything
    'paycvv'         => $paycvv,
    'payname'        => $payname,
    'discount_term'  => $discount_term,
    'pkgnum'         => $session->{'pkgnum'},
    map { $_ => $p->{$_} } ( @{ $payby2fields{$payby} },
                             qw( save auto ),
                           )
  };

}

sub store_payment {
  my $p = shift;

  my $validate = validate_payment($p);
  return $validate if $validate->{'error'};

  my $conf = new FS::Conf;
  my $timeout = $conf->config('selfservice-session_timeout') || '1 hour'; #?
  _cache->set( 'payment_'.$p->{'session_id'}, $validate, $timeout );

  +{ map { $_=>$validate->{$_} }
      qw( card_type paymask payname paydate_pretty amount )
  };

}

sub process_stored_payment {
  my $p = shift;

  my $session_id = $p->{'session_id'};

  my $payment_info = _cache->get( "payment_$session_id" )
    or return { 'error' => "Can't resume session" }; #better error message

  do_process_payment($payment_info);

}

sub process_payment {
  my $p = shift;

  my $payment_info = validate_payment($p);
  return $payment_info if $payment_info->{'error'};

  do_process_payment($payment_info);

}

sub do_process_payment {
  my $validate = shift;

  my $cust_main = $validate->{'cust_main'};

  my $amount = delete $validate->{'amount'};
  my $paynum = '';

  my $payby = delete $validate->{'payby'};

  my $error = $cust_main->realtime_bop( $FS::payby::payby2bop{$payby}, $amount,
    'quiet'       => 1,
    'selfservice' => 1,
    'paynum_ref'  => \$paynum,
    %$validate,
  );
  return { 'error' => $error } if $error;

  $cust_main->apply_payments;

  if ( $validate->{'save'} ) {
    my $new = new FS::cust_main { $cust_main->hash };
    if ($validate->{'payby'} eq 'CARD' || $validate->{'payby'} eq 'DCRD') {
      $new->set( $_ => $validate->{$_} )
        foreach qw( payname paystart_month paystart_year payissue payip
                    address1 address2 city state zip country );
      $new->set( 'payby' => $validate->{'auto'} ? 'CARD' : 'DCRD' );
    } elsif ($payby eq 'CHEK' || $payby eq 'DCHK') {
      $new->set( $_ => $validate->{$_} )
        foreach qw( payname payip paytype paystate
                    stateid stateid_state );
      $new->set( 'payby' => $validate->{'auto'} ? 'CHEK' : 'DCHK' );
    }
    $new->set( 'payinfo' => $cust_main->card_token || $validate->{'payinfo'} );
    $new->set( 'paydate' => $validate->{'paydate'} );
    my $error = $new->replace($cust_main);
    if ( $error ) {
      #no, this causes customers to process their payments again
      #return { 'error' => $error };
      #XXX just warn verosely for now so i can figure out how these happen in
      # the first place, eventually should redirect them to the "change
      #address" page but indicate the payment did process??
      delete($validate->{'payinfo'}); #don't want to log this!
      warn "WARNING: error changing customer info when processing payment (not returning to customer as a processing error): $error\n".
           "NEW: ". Dumper($new)."\n".
           "OLD: ". Dumper($cust_main)."\n".
           "PACKET: ". Dumper($validate)."\n";
    #} else {
      #not needed...
      #$cust_main = $new;
    }
  }

  my $cust_pay = '';
  my $receipt_html = '';
  if ($paynum) {
      # currently supported for realtime CC only; send receipt data to SS
      $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } );
      if($cust_pay) {
	$receipt_html = qq!
<TABLE BGCOLOR="#cccccc" BORDER=0 CELLSPACING=2>

<TR>
  <TD ALIGN="right">Payment#</TD>
  <TD BGCOLOR="#FFFFFF"><B>! . $cust_pay->paynum . qq!</B></TD>
</TR>

<TR>
  <TD ALIGN="right">Date</TD>

  <TD BGCOLOR="#FFFFFF"><B>! . 
	time2str("%a&nbsp;%b&nbsp;%o,&nbsp;%Y&nbsp;%r", $cust_pay->_date)
							    . qq!</B></TD>
</TR>


<TR>
  <TD ALIGN="right">Amount</TD>
  <TD BGCOLOR="#FFFFFF"><B>! . sprintf('%.2f', $cust_pay->paid) . qq!</B></TD>

</TR>

<TR>
  <TD ALIGN="right">Payment method</TD>
  <TD BGCOLOR="#FFFFFF"><B>! . $cust_pay->payby_name .' #'. $cust_pay->paymask
								. qq!</B></TD>
</TR>

</TABLE>
!;
      }
  }

  if ( $cust_pay ) {

    my($gw, $auth, $order) = split(':', $cust_pay->paybatch);

    return {
      'error'        => '',
      'amount'       => sprintf('%.2f', $cust_pay->paid),
      'date'         => $cust_pay->_date,
      'date_pretty'  => time2str('%Y-%m-%d', $cust_pay->_date),
      'time_pretty'  => time2str('%T', $cust_pay->_date),
      'auth_num'     => $auth,
      'order_num'    => $order,
      'receipt_html' => $receipt_html,
    };

  } else {

    return {
      'error'        => '',
      'receipt_html' => '',
    };

  }

}

sub realtime_collect {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $amount;
  if ( $p->{'amount'} ) {
    $amount = $p->{'amount'};
  }
  elsif ( $session->{'pkgnum'} ) {
    $amount = $cust_main->balance_pkgnum( $session->{'pkgnum'} );
  }
  else {
    $amount = $cust_main->balance;
  }

  my $error = $cust_main->realtime_collect(
    'method'     => $p->{'method'},
    'amount'     => $amount,
    'pkgnum'     => $session->{'pkgnum'},
    'session_id' => $p->{'session_id'},
    'apply'      => 1,
    'selfservice'=> 1,
  );
  return { 'error' => $error } unless ref( $error );

  return { 'error' => '', amount => $amount, %$error };
}

sub process_payment_order_pkg {
  my $p = shift;

  my $hr = process_payment($p);
  return $hr if $hr->{'error'};

  order_pkg($p);
}

sub process_payment_order_renew {
  my $p = shift;

  my $hr = process_payment($p);
  return $hr if $hr->{'error'};

  order_renew($p);
}

sub process_prepay {

  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my %return;

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my( $amount, $seconds, $upbytes, $downbytes, $totalbytes ) = ( 0, 0, 0, 0, 0 );
  my $error = $cust_main->recharge_prepay( $p->{'prepaid_cardnum'},
                                           \$amount,
                                           \$seconds,
                                           \$upbytes,
                                           \$downbytes,
                                           \$totalbytes,
                                         );

  return { 'error' => $error } if $error;

  return { 'error'     => '',
           'amount'    => $amount,
           'seconds'   => $seconds,
           'duration'  => duration_exact($seconds),
           'upbytes'   => $upbytes,
           'upload'    => FS::UI::bytecount::bytecount_unexact($upbytes),
           'downbytes' => $downbytes,
           'download'  => FS::UI::bytecount::bytecount_unexact($downbytes),
           'totalbytes'=> $totalbytes,
           'totalload' => FS::UI::bytecount::bytecount_unexact($totalbytes),
         };

}

sub invoice {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $invnum = $p->{'invnum'};

  my $cust_bill = qsearchs('cust_bill', { 'invnum'  => $invnum,
                                          'custnum' => $custnum } )
    or return { 'error' => "Can't find invnum" };

  #my %return;

  return { 'error'        => '',
           'invnum'       => $invnum,
           'invoice_text' => join('', $cust_bill->print_text ),
           'invoice_html' => $cust_bill->print_html( { unsquelch_cdr => 1 } ),
         };

}

sub invoice_pdf {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $invnum = $p->{'invnum'};

  my $cust_bill = qsearchs('cust_bill', { 'invnum'  => $invnum,
                                          'custnum' => $custnum } )
    or return { 'error' => "Can't find invnum" };

  #my %return;

  return { 'error'       => '',
           'invnum'      => $invnum,
           'invoice_pdf' => $cust_bill->print_pdf({
                              'unsquelch_cdr' => 1,
                              'locale'        => $p->{'locale'},
                            }),
         };

}

sub legacy_invoice {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $legacyinvnum = $p->{'legacyinvnum'};

  my %hash = (
    'legacyinvnum' => $legacyinvnum,
    'custnum'      => $custnum,
  );

  my $legacy_cust_bill =
         qsearchs('legacy_cust_bill', { %hash, 'locale' => $p->{'locale'} } )
      || qsearchs('legacy_cust_bill', \%hash )
    or return { 'error' => "Can't find legacyinvnum" };

  #my %return;

  return { 'error'        => '',
           'legacyinvnum' => $legacyinvnum,
           'legacyid'     => $legacy_cust_bill->legacyid,
           'invoice_html' => $legacy_cust_bill->content_html,
         };

}

sub legacy_invoice_pdf {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $legacyinvnum = $p->{'legacyinvnum'};

  my $legacy_cust_bill = qsearchs('legacy_cust_bill', {
    'legacyinvnum' => $legacyinvnum,
    'custnum'      => $custnum,
  }) or return { 'error' => "Can't find legacyinvnum" };

  #my %return;

  return { 'error'        => '',
           'legacyinvnum' => $legacyinvnum,
           'legacyid'     => $legacy_cust_bill->legacyid,
           'invoice_pdf'  => $legacy_cust_bill->content_pdf,
         };

}

sub invoice_logo {
  my $p = shift;

  #sessioning for this?  how do we get the session id to the backend invoice
  # template so it can add it to the link, blah

  my $agentnum = '';
  if ( $p->{'invnum'} ) {
    my $cust_bill = qsearchs('cust_bill', { 'invnum' => $p->{'invnum'} } )
      or return { 'error' => 'unknown invnum' };
    $agentnum = $cust_bill->cust_main->agentnum;
  }

  my $templatename = $p->{'template'} || $p->{'templatename'};

  #false laziness-ish w/view/cust_bill-logo.cgi

  my $conf = new FS::Conf;
  if ( $templatename =~ /^([^\.\/]*)$/ && $conf->exists("logo_$1.png") ) {
    $templatename = "_$1";
  } else {
    $templatename = '';
  }

  my $filename = "logo$templatename.png";

  return { 'error'        => '',
           'logo'         => $conf->config_binary($filename, $agentnum),
           'content_type' => 'image/png', #should allow gif, jpg too
         };
}


sub list_invoices {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $conf = new FS::Conf;

  my @legacy_cust_bill = $cust_main->legacy_cust_bill;

  my @cust_bill = grep ! $_->hide, $cust_main->cust_bill;

  my $balance = 0;

  return  { 'error'       => '',
            'balance'     => $cust_main->balance,
            'invoices'    => [
              map {
                    my $owed = $_->owed;
                    $balance += $owed;
                    +{ 'invnum'       => $_->invnum,
                       '_date'        => $_->_date,
                       'date'         => time2str("%b %o, %Y", $_->_date),
                       'date_short'   => time2str("%m-%d-%Y",  $_->_date),
                       'previous'     => sprintf('%.2f', ($_->previous)[0]),
                       'charged'      => sprintf('%.2f', $_->charged),
                       'owed'         => sprintf('%.2f', $owed),
                       'balance'      => sprintf('%.2f', $balance),
                     }
                  }
                  @cust_bill
            ],
            'legacy_invoices' => [
              map {
                    +{ 'legacyinvnum' => $_->legacyinvnum,
                       'legacyid'     => $_->legacyid,
                       '_date'        => $_->_date,
                       'date'         => time2str("%b %o, %Y", $_->_date),
                       'date_short'   => time2str("%m-%d-%Y",  $_->_date),
                       'charged'      => sprintf('%.2f', $_->charged),
                       'has_content'  => (    length($_->content_pdf)
                                           || length($_->content_html) ),
                     }
                  }
                  @legacy_cust_bill
            ],
          };
}

sub cancel {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my @errors = $cust_main->cancel( 'quiet'=>1 );

  my $error = scalar(@errors) ? join(' / ', @errors) : '';

  return { 'error' => $error };

}

sub list_pkgs {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $conf = new FS::Conf;
  
# the duplication below is necessary:
# 1. to maintain the current buggy behaviour wrt the cust_pkg and part_pkg
# hashes overwriting each other (setup and no_auto fields). Fixing that is a
# non-backwards-compatible change breaking the software of anyone using the API
# instead of the stock selfservice
# 2. to return cancelled packages as well - for wholesale and non-wholesale
  if( $conf->exists('selfservice_server-view-wholesale') ) {
    return { 'svcnum'   => $session->{'svcnum'},
	    'custnum'  => $custnum,
	    'cust_pkg' => [ map {
                          { $_->hash,
                            part_pkg => [ map $_->hashref, $_->part_pkg ],
                            part_svc =>
                              [ map $_->hashref, $_->available_part_svc ],
                            cust_svc => 
                              [ map { my $ref = { $_->hash,
                                                  label => [ $_->label ],
                                                };
                                      $ref->{_password} = $_->svc_x->_password
                                        if $context eq 'agent'
                                        && $conf->exists('agent-showpasswords')
                                        && $_->part_svc->svcdb eq 'svc_acct';
                                      $ref;
                                    } $_->cust_svc
                              ],
                          };
                        } $cust_main->cust_pkg
                  ],
    'small_custview' =>
      small_custview( $cust_main, $conf->config('countrydefault') ),
    'wholesale_view' => 1,
    'login_svcpart' => [ $conf->config('selfservice_server-login_svcpart') ],
    'date_format' => $conf->config('date_format') || '%m/%d/%Y',
    'lnp' => $conf->exists('svc_phone-lnp'),
      };
  }

  { 'svcnum'   => $session->{'svcnum'},
    'custnum'  => $custnum,
    'cust_pkg' => [ map {
                          my $primary_cust_svc = $_->primary_cust_svc;
                          +{ $_->hash,
                            $_->part_pkg->hash,
                            status => $_->status,
                            part_svc =>
                              [ map $_->hashref, $_->available_part_svc ],
                            cust_svc => 
                              [ map { my $ref = { $_->hash,
                                                  label => [ $_->label ],
                                                };
                                      $ref->{_password} = $_->svc_x->_password
                                        if $context eq 'agent'
                                        && $conf->exists('agent-showpasswords')
                                        && $_->part_svc->svcdb eq 'svc_acct';
                                      $ref->{svchash} = { $_->svc_x->hash } if 
                                        $_->part_svc->svcdb eq 'svc_phone';
                                      $ref->{svchash}->{svcpart} =  $_->part_svc->svcpart
                                        if $_->part_svc->svcdb eq 'svc_phone'; # hack
                                      $ref;
                                    } $_->cust_svc
                              ],
                            primary_cust_svc =>
                              $primary_cust_svc
                                ? { $primary_cust_svc->hash,
                                    label => [ $primary_cust_svc->label ],
                                    finger => $primary_cust_svc->svc_x->finger, #uuh
                                    $primary_cust_svc->part_svc->hash,
                                  }
                                : {}, #'' ?
                          };
                        } $cust_main->ncancelled_pkgs
                  ],
    'small_custview' =>
      small_custview( $cust_main, $conf->config('countrydefault') ),
  };

}

sub list_svcs {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $session->{'pkgnum'} || $p->{'pkgnum'} || '';
  if ( ! $pkgnum && $p->{'svcnum'} ) {
    my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $p->{'svcnum'} } );
    $pkgnum = $cust_svc->pkgnum if $cust_svc;
  }

  my @cust_svc = ();
  #foreach my $cust_pkg ( $cust_main->ncancelled_pkgs ) {
  foreach my $cust_pkg ( $p->{'ncancelled'} 
                         ? $cust_main->ncancelled_pkgs
                         : $cust_main->unsuspended_pkgs ) {
    next if $pkgnum && $cust_pkg->pkgnum != $pkgnum;
    push @cust_svc, @{[ $cust_pkg->cust_svc ]}; #@{[ ]} to force array context
  }
  if ( $p->{'svcdb'} ) {
    my $svcdb = ref($p->{'svcdb'}) eq 'HASH'
                  ? $p->{'svcdb'}
                  : ref($p->{'svcdb'}) eq 'ARRAY'
                    ? { map { $_=>1 } @{ $p->{'svcdb'} } }
                    : { $p->{'svcdb'} => 1 };
    @cust_svc = grep $svcdb->{ $_->part_svc->svcdb }, @cust_svc
  }

  #@svc_x = sort { $a->domain cmp $b->domain || $a->username cmp $b->username }
  #              @svc_x;

    my $conf = new FS::Conf;

  { 
    'svcnum'   => $session->{'svcnum'},
    'custnum'  => $custnum,
    'date_format' => $conf->config('date_format') || '%m/%d/%Y',
    'view_usage_nodomain' => $conf->exists('selfservice-view_usage_nodomain'),
    'svcs'     => [
      map { 
            my $svc_x = $_->svc_x;
            my($label, $value) = $_->label;
            my $svcdb = $_->part_svc->svcdb;
            my $cust_pkg = $_->cust_pkg;
            my $part_pkg = $cust_pkg->part_pkg;

            my %hash = (
              'svcnum'     => $_->svcnum,
              'svcdb'      => $svcdb,
              'label'      => $label,
              'value'      => $value,
              'pkg_status' => $cust_pkg->status,
            );

            if ( $svcdb eq 'svc_acct' ) {
              %hash = (
                %hash,
                'username'   => $svc_x->username,
                'email'      => $svc_x->email,
                'finger'     => $svc_x->finger,
                'seconds'    => $svc_x->seconds,
                'upbytes'    => display_bytecount($svc_x->upbytes),
                'downbytes'  => display_bytecount($svc_x->downbytes),
                'totalbytes' => display_bytecount($svc_x->totalbytes),

                'recharge_amount'  => $part_pkg->option('recharge_amount',1),
                'recharge_seconds' => $part_pkg->option('recharge_seconds',1),
                'recharge_upbytes'    =>
                  display_bytecount($part_pkg->option('recharge_upbytes',1)),
                'recharge_downbytes'  =>
                  display_bytecount($part_pkg->option('recharge_downbytes',1)),
                'recharge_totalbytes' =>
                  display_bytecount($part_pkg->option('recharge_totalbytes',1)),
                # more...
              );

            } elsif ( $svcdb eq 'svc_dsl' ) {
              $hash{'phonenum'} = $svc_x->phonenum;
              if ( $svc_x->first || $svc_x->get('last') || $svc_x->company ) {
                $hash{'name'} = $svc_x->first. ' '. $svc_x->get('last');
                $hash{'name'} = $svc_x->company. ' ('. $hash{'name'}. ')'
                  if $svc_x->company;
              } else {
                $hash{'name'} = $cust_main->name;
              }
            }
            # elsif ( $svcdb eq 'svc_phone' || $svcdb eq 'svc_port' ) {
            #  %hash = (
            #    %hash,
            #  );
            #}

            \%hash;
          }
          @cust_svc
    ],
  };

}

sub _customer_svc_x {
  my($custnum, $svcnum, $table) = (shift, shift, shift);
  my $hashref = ref($svcnum) ? $svcnum : { 'svcnum' => $svcnum };

  $custnum =~ /^(\d+)$/ or die "illegal custnum";
  my $search = " AND custnum = $1";
  #$search .= " AND agentnum = ". $session->{'agentnum'} if $context eq 'agent';

  qsearchs( {
    'table'     => ($table || 'svc_acct'),
    'addl_from' => 'LEFT JOIN cust_svc  USING ( svcnum  ) '.
                   'LEFT JOIN cust_pkg  USING ( pkgnum  ) ',#.
                   #'LEFT JOIN cust_main USING ( custnum ) ',
    'hashref'   => $hashref,
    'extra_sql' => $search, #important
  } );

}

sub svc_status_html {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  #XXX only svc_dsl for now
  my $svc_x = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_dsl')
    or return { 'error' => "Service not found" };

  my $html = $svc_x->getstatus_html;

  return { 'html' => $html };

}

sub acct_forward_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $svc_forward = _customer_svc_x( $custnum,
                                     { 'srcsvc' => $p->{'svcnum'} },
                                     'svc_forward',
                                   )
    or return { 'error' => '',
                'dst'   => '',
              };

  return { 'error' => '',
           'dst'   => $svc_forward->dst || $svc_forward->dstsvc_acct->email,
         };

}

sub process_acct_forward {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $old = _customer_svc_x( $custnum,
                             { 'srcsvc' => $p->{'svcnum'} },
                             'svc_forward',
                           );

  if ( $p->{'dst'} eq '' ) {
    if ( $old ) {
      my $error = $old->delete;
      return { 'error' => $error };
    }
    return { 'error' => '' };
  }

  my $new = new FS::svc_forward { 'srcsvc' => $p->{'svcnum'},
                                  'dst'    => $p->{'dst'},
                                };

  my $error;
  if ( $old ) {
    $new->svcnum($old->svcnum);
    my $cust_svc = $old->cust_svc;
    $new->svcpart($old->svcpart);
    $new->pkgnuym($old->pkgnum);
    $error = $new->replace($old);
  } else {
    my $conf = new FS::Conf;
    $new->svcpart($conf->config('selfservice-svc_forward_svcpart'));

    my $svc_acct = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_acct' )
      or return { 'error' => 'No service' }; #how would we even get here?

    $new->pkgnum( $svc_acct->cust_svc->pkgnum );

    $error = $new->insert;
  }

  return { 'error' => $error };

}

sub list_dsl_devices {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $svc_dsl = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_dsl' )
    or return { 'error' => "Service not found" };

  return {
    'devices' => [ map {
                         +{ 'mac_addr' => $_->mac_addr };
                       } $svc_dsl->dsl_device
                 ],
  };

}

sub add_dsl_device {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $svc_dsl = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_dsl' )
    or return { 'error' => "Service not found" };

  return { 'error' => 'No MAC address supplied' }
    unless length($p->{'mac_addr'});

  my $dsl_device = new FS::dsl_device { 'svcnum'   => $svc_dsl->svcnum,
                                        'mac_addr' => scalar($p->{'mac_addr'}),
                                      };
  my $error = $dsl_device->insert;
  return { 'error' => $error };

}

sub delete_dsl_device {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $svc_dsl = _customer_svc_x( $custnum, $p->{'svcnum'}, 'svc_dsl' )
    or return { 'error' => "Service not found" };

  my $dsl_device = qsearchs('dsl_device', { 'svcnum'   => $svc_dsl->svcnum,
                                            'mac_addr' => scalar($p->{'mac_addr'}),
                                          }
                           )
    or return { 'error' => 'Unknown MAC address: '. $p->{'mac_addr'} };

  my $error = $dsl_device->delete;
  return { 'error' => $error };

}

sub port_graph {
  my $p = shift;
  _usage_details( \&_port_graph, $p,
                  'svcdb' => 'svc_port',
                );
}

sub _port_graph {
  my($svc_port, $begin, $end) = @_;
  my @usage = ();
  my $pngOrError = $svc_port->graph_png( start=>$begin, end=> $end );
  push @usage, { 'png' => $pngOrError };
  (@usage);
}

sub _list_svc_usage {
  my($svc_acct, $begin, $end) = @_;
  my @usage = ();
  foreach my $part_export ( 
    map { qsearch ( 'part_export', { 'exporttype' => $_ } ) }
    qw( sqlradius sqlradius_withdomain )
  ) {
    push @usage, @ { $part_export->usage_sessions($begin, $end, $svc_acct) };
  }
  (@usage);
}

sub list_svc_usage {
  _usage_details(\&_list_svc_usage, @_);
}

sub _list_support_usage {
  my($svc_acct, $begin, $end) = @_;
  my @usage = ();
  foreach ( grep { $begin <= $_->_date && $_->_date <= $end }
            qsearch('acct_rt_transaction', { 'svcnum' => $svc_acct->svcnum })
          ) {
    push @usage, { 'seconds'  => $_->seconds,
                   'support'  => $_->support,
                   '_date'    => $_->_date,
                   'id'       => $_->transaction_id,
                   'creator'  => $_->creator,
                   'subject'  => $_->subject,
                   'status'   => $_->status,
                   'ticketid' => $_->ticketid,
                 };
  }
  (@usage);
}

sub list_support_usage {
  _usage_details(\&_list_support_usage, @_);
}

sub _list_cdr_usage {
  my($svc_phone, $begin, $end) = @_;
  map [ $_->downstream_csv('format' => 'default', 'keeparray' => 1) ], #XXX config for format
                       $svc_phone->get_cdrs( 'begin'=>$begin, 'end'=>$end, );
}

sub list_cdr_usage {
  my $p = shift;
  _usage_details( \&_list_cdr_usage, $p,
                  'svcdb' => 'svc_phone',
                );
}

sub _usage_details {
  my($callback, $p, %opt) = @_;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'svcnum' => $p->{'svcnum'} };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';

  my $svcdb = $opt{'svcdb'} || 'svc_acct';

  my $svc_x = qsearchs( $svcdb, $search );
  return { 'error' => 'No service selected in list_svc_usage' } 
    unless $svc_x;

  my $header = $svcdb eq 'svc_phone'
                 ? [ split(',', FS::cdr::invoice_header('default') ) ]  #XXX
                 : [];

  my $cust_pkg = $svc_x->cust_svc->cust_pkg;
  my $freq     = $cust_pkg->part_pkg->freq;
  my $start    = $cust_pkg->setup;
  #my $end      = $cust_pkg->bill; # or time?
  my $end      = time;

  unless ( $p->{beginning} ) {
    $p->{beginning} = $cust_pkg->last_bill;
    $p->{ending}    = $end;
  }

  my (@usage) = &$callback($svc_x, $p->{beginning}, $p->{ending});

  #kinda false laziness with FS::cust_main::bill, but perhaps
  #we should really change this bit to DateTime and DateTime::Duration
  #
  #change this bit to use Date::Manip? CAREFUL with timezones (see
  # mailing list archive)
  my ($nsec,$nmin,$nhour,$nmday,$nmon,$nyear) =
    (localtime($p->{ending}) )[0,1,2,3,4,5];
  my ($psec,$pmin,$phour,$pmday,$pmon,$pyear) =
    (localtime($p->{beginning}) )[0,1,2,3,4,5];

  if ( $freq =~ /^\d+$/ ) {
    $nmon += $freq;
    until ( $nmon < 12 ) { $nmon -= 12; $nyear++; }
    $pmon -= $freq;
    until ( $pmon >= 0 ) { $pmon += 12; $pyear--; }
  } elsif ( $freq =~ /^(\d+)w$/ ) {
    my $weeks = $1;
    $nmday += $weeks * 7;
    $pmday -= $weeks * 7;
  } elsif ( $freq =~ /^(\d+)d$/ ) {
    my $days = $1;
    $nmday += $days;
    $pmday -= $days;
  } elsif ( $freq =~ /^(\d+)h$/ ) {
    my $hours = $1;
    $nhour += $hours;
    $phour -= $hours;
  } else {
    return { 'error' => "unparsable frequency: ". $freq };
  }
  
  my $previous  = timelocal_nocheck($psec,$pmin,$phour,$pmday,$pmon,$pyear);
  my $next      = timelocal_nocheck($nsec,$nmin,$nhour,$nmday,$nmon,$nyear);

  { 
    'error'     => '',
    'svcnum'    => $p->{svcnum},
    'beginning' => $p->{beginning},
    'ending'    => $p->{ending},
    'previous'  => ($previous > $start) ? $previous : $start,
    'next'      => ($next < $end) ? $next : $end,
    'header'    => $header,
    'usage'     => \@usage,
  };
}

sub order_pkg {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $status = $cust_main->status;
  #false laziness w/ClientAPI/Signup.pm

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum' => $custnum,
    'pkgpart' => $p->{'pkgpart'},
  } );
  my $error = $cust_pkg->check;
  return { 'error' => $error } if $error;

  my @svc = ();
  unless ( $p->{'svcpart'} eq 'none' ) {

    my $svcdb;
    my $svcpart = '';
    if ( $p->{'svcpart'} =~ /^(\d+)$/ ) {
      $svcpart = $1;
      my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
      return { 'error' => "Unknown svcpart $svcpart" } unless $part_svc;
      $svcdb = $part_svc->svcdb;
    } else {
      $svcdb = 'svc_acct';
    }
    $svcpart ||= $cust_pkg->part_pkg->svcpart($svcdb);

    my %fields = (
      'svc_acct'     => [ qw( username domsvc _password sec_phrase popnum ) ],
      'svc_domain'   => [ qw( domain ) ],
      'svc_phone'    => [ qw( phonenum pin sip_password phone_name ) ],
      'svc_external' => [ qw( id title ) ],
      'svc_pbx'      => [ qw( id title ) ],
    );
  
    my $svc_x = "FS::$svcdb"->new( {
      'svcpart'   => $svcpart,
      map { $_ => $p->{$_} } @{$fields{$svcdb}}
    } );
    
    if ( $svcdb eq 'svc_acct' && exists($p->{"snarf_machine1"}) ) {
      my @acct_snarf;
      my $snarfnum = 1;
      while ( length($p->{"snarf_machine$snarfnum"}) ) {
        my $acct_snarf = new FS::acct_snarf ( {
          'machine'   => $p->{"snarf_machine$snarfnum"},
          'protocol'  => $p->{"snarf_protocol$snarfnum"},
          'username'  => $p->{"snarf_username$snarfnum"},
          '_password' => $p->{"snarf_password$snarfnum"},
        } );
        $snarfnum++;
        push @acct_snarf, $acct_snarf;
      }
      $svc_x->child_objects( \@acct_snarf );
    }
    
    my $y = $svc_x->setdefault; # arguably should be in new method
    return { 'error' => $y } if $y && !ref($y);
  
    $error = $svc_x->check;
    return { 'error' => $error } if $error;

    push @svc, $svc_x;

  }

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => \@svc );
  #msgcat
  $error = $cust_main->order_pkgs( \%hash, 'noexport' => 1 );
  return { 'error' => $error } if $error;

  my $conf = new FS::Conf;
  if ( $conf->exists('signup_server-realtime') ) {

    my $bill_error = _do_bop_realtime( $cust_main, $status );

    if ($bill_error) {
      $cust_pkg->cancel('quiet'=>1);
      return $bill_error;
    } else {
      $cust_pkg->reexport;
    }

  } else {
    $cust_pkg->reexport;
  }

  my $svcnum = $svc[0] ? $svc[0]->svcnum : '';

  return { error=>'', pkgnum=>$cust_pkg->pkgnum, svcnum=>$svcnum };

}

sub change_pkg {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $status = $cust_main->status;
  my $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $p->{pkgnum} } )
    or return { 'error' => "unknown package $p->{pkgnum}" };

  my @newpkg;
  my $error = FS::cust_pkg::order( $custnum,
                                   [$p->{pkgpart}],
                                   [$p->{pkgnum}],
                                   \@newpkg,
                                 );

  my $conf = new FS::Conf;
  if ( $conf->exists('signup_server-realtime') ) {

    my $bill_error = _do_bop_realtime( $cust_main, $status );

    if ($bill_error) {
      $newpkg[0]->suspend;
      return $bill_error;
    } else {
      $newpkg[0]->reexport;
    }

  } else {  
    $newpkg[0]->reexport;
  }

  return { error => '', pkgnum => $cust_pkg->pkgnum };

}

sub order_recharge {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $status = $cust_main->status;
  my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $p->{'svcnum'} } )
    or return { 'error' => "unknown service " . $p->{'svcnum'} };

  my $svc_x = $cust_svc->svc_x;
  my $part_pkg = $cust_svc->cust_pkg->part_pkg;

  my %vhash =
    map { $_ =~ /^recharge_(.*)$/; $1, $part_pkg->option($_, 1) } 
    qw ( recharge_seconds recharge_upbytes recharge_downbytes
         recharge_totalbytes );
  my $amount = $part_pkg->option('recharge_amount', 1); 
  
  my ($l, $v, $d) = $cust_svc->label;  # blah
  my $pkg = "Recharge $v"; 

  my $bill_error = $cust_main->charge($amount, $pkg,
     "time: $vhash{seconds}, up: $vhash{upbytes}," . 
     "down: $vhash{downbytes}, total: $vhash{totalbytes}",
     $part_pkg->taxclass); #meh

  my $conf = new FS::Conf;
  if ( $conf->exists('signup_server-realtime') && !$bill_error ) {

    $bill_error = _do_bop_realtime( $cust_main, $status );

    if ($bill_error) {
      return $bill_error;
    } else {
      my $error = $svc_x->recharge (\%vhash);
      return { 'error' => $error } if $error;
    }

  } else {  
    my $error = $bill_error;
    $error ||= $svc_x->recharge (\%vhash);
    return { 'error' => $error } if $error;
  }

  return { error => '', svc => $cust_svc->part_svc->svc };

}

sub _do_bop_realtime {
  my ($cust_main, $status) = (shift, shift);

    my $old_balance = $cust_main->balance;

    my $bill_error =    $cust_main->bill
                     || $cust_main->apply_payments_and_credits
                     || $cust_main->realtime_collect('selfservice' => 1);

    if (    $cust_main->balance > $old_balance
         && $cust_main->balance > 0
         && ( $cust_main->payby !~ /^(BILL|DCRD|DCHK)$/ ?
              1 : $status eq 'suspended' ) ) {
      #this makes sense.  credit is "un-doing" the invoice
      my $conf = new FS::Conf;
      $cust_main->credit( sprintf("%.2f", $cust_main->balance - $old_balance ),
                          'self-service decline',
                          'reason_type' => $conf->config('signup_credit_type'),
                        );
      $cust_main->apply_credits( 'order' => 'newest' );

      return { 'error' => '_decline', 'bill_error' => $bill_error };
    }

    '';
}

sub renew_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my @cust_pkg = sort { $a->bill <=> $b->bill }
                 grep { $_->part_pkg->freq ne '0' }
                 $cust_main->ncancelled_pkgs;

  #return { 'error' => 'No active packages to renew.' } unless @cust_pkg;

  my $total = $cust_main->balance;

  my @array = map {
                    my $bill = $_->bill;
                    $total += $_->part_pkg->base_recur($_, \$bill);
                    my $renew_date = $_->part_pkg->add_freq($_->bill);
                    {
                      'pkgnum'             => $_->pkgnum,
                      'amount'             => sprintf('%.2f', $total),
                      'bill_date'          => $_->bill,
                      'bill_date_pretty'   => time2str('%x', $_->bill),
                      'renew_date'         => $renew_date,
                      'renew_date_pretty'  => time2str('%x', $renew_date),
                      'expire_date'        => $_->expire,
                      'expire_date_pretty' => time2str('%x', $_->expire),
                    };
                  }
                  @cust_pkg;

  return { 'dates' => \@array };

}

sub payment_info_renew_info {
  my $p = shift;
  my $renew_info   = renew_info($p);
  my $payment_info = payment_info($p);
  return { %$renew_info,
           %$payment_info,
         };
}

sub order_renew {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $date = $p->{'date'};

  my $now = time;

  #freeside-daily -n -d $date fs_daily $custnum
  $cust_main->bill_and_collect( 'time'         => $date,
                                'invoice_time' => $now,
                                'actual_time'  => $now,
                                'check_freq'   => '1d',
                              );

  return { 'error' => '' };

}

sub suspend_pkg {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $conf = new FS::Conf;
  my $reasonnum = 
    $conf->config('selfservice-self_suspend_reason', $cust_main->agentnum)
      or return { 'error' => 'Permission denied' };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,   } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $error = $cust_pkg->suspend(reason => $reasonnum);
  return { 'error' => $error };

}

sub cancel_pkg {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,   } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $error = $cust_pkg->cancel('quiet' => 1);
  return { 'error' => $error };

}

sub provision_phone {
 my $p = shift;
 my @bulkdid;
 @bulkdid = @{$p->{'bulkdid'}} if $p->{'bulkdid'};

 if($p->{'svcnum'} && $p->{'svcnum'} =~ /^\d+$/){
      my($context, $session, $custnum) = _custoragent_session_custnum($p);
      return { 'error' => $session } if $context eq 'error';
    
      my $svc_phone = qsearchs('svc_phone', { svcnum => $p->{'svcnum'} });
      return { 'error' => 'service not found' } unless $svc_phone;
      return { 'error' => 'invalid svcnum' } 
        if $svc_phone && $svc_phone->cust_svc->cust_pkg->custnum != $custnum;

      $svc_phone->email($p->{'email'}) 
        if $svc_phone->email ne $p->{'email'} && $p->{'email'} =~ /^([\w\.\d@]+|)$/;
      $svc_phone->forwarddst($p->{'forwarddst'}) 
        if $svc_phone->forwarddst ne $p->{'forwarddst'} 
            && $p->{'forwarddst'} =~ /^(\d+|)$/;
      return { 'error' => $svc_phone->replace };
 }

# single DID LNP
 unless($p->{'lnp'}) {
    $p->{'lnp_desired_due_date'} = parse_datetime($p->{'lnp_desired_due_date'});
    $p->{'lnp_status'} = "portingin";
    return _provision( 'FS::svc_phone',
		  [qw(lnp_desired_due_date lnp_other_provider 
		    lnp_other_provider_account phonenum countrycode lnp_status)],
		  [qw(phonenum countrycode)],
		  $p,
		  @_
		);
 }

# single DID order
 unless (scalar(@bulkdid)) {
    return _provision( 'FS::svc_phone',
		  [qw(phonenum countrycode)],
		  [qw(phonenum countrycode)],
		  $p,
		  @_
		);
 }

# bulk DID order case
  my $error;
  foreach my $did ( @bulkdid ) {
    $did =~ s/[^0-9]//g;
    $error = _provision( 'FS::svc_phone',
	      [qw(phonenum countrycode)],
	      [qw(phonenum countrycode)],
	      {
		'pkgnum' => $p->{'pkgnum'},
		'svcpart' => $p->{'svcpart'},
		'phonenum' => $did,
		'countrycode' => $p->{'countrycode'},
		'session_id' => $p->{'session_id'},
	      }
	    );
    return $error if ($error->{'error'} && length($error->{'error'}) > 1);
  }
  { 'bulkdid' => [ @bulkdid ], 'svc' => $error->{'svc'} }
}

sub provision_acct {
  my $p = shift;
  warn "provision_acct called\n"
    if $DEBUG;

  return { 'error' => gettext('passwords_dont_match') }
    if $p->{'_password'} ne $p->{'_password2'};
  return { 'error' => gettext('empty_password') }
    unless length($p->{'_password'});
 
  if ($p->{'domsvc'}) {
    my %domains = domain_select_hash FS::svc_acct(map { $_ => $p->{$_} }
                                                  qw ( svcpart pkgnum ) );
    return { 'error' => gettext('invalid_domain') }
      unless ($domains{$p->{'domsvc'}});
  }

  warn "provision_acct calling _provision\n"
    if $DEBUG;
  _provision( 'FS::svc_acct',
              [qw(username _password domsvc)],
              [qw(username _password domsvc)],
              $p,
              @_
            );
}

sub provision_external {
  my $p = shift;
  #_provision( 'FS::svc_external', [qw(id title)], [qw(id title)], $p, @_ );
  _provision( 'FS::svc_external',
              [],
              [qw(id title)],
              $p,
              @_
            );
}

sub _provision {
  my( $class, $fields, $return_fields, $p ) = splice(@_, 0, 4);
  warn "_provision called for $class\n"
    if $DEBUG;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  warn "searching for custnum $custnum pkgnum $pkgnum\n"
    if $DEBUG;
  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,
                                                               } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  warn "searching for svcpart ". $p->{'svcpart'}. "\n"
    if $DEBUG;
  my $part_svc = qsearchs('part_svc', { 'svcpart' => $p->{'svcpart'} } )
    or return { 'error' => "unknown svcpart $p->{'svcpart'}" };

  warn "creating $class record\n"
    if $DEBUG;
  my $svc_x = $class->new( {
    'pkgnum'  => $p->{'pkgnum'},
    'svcpart' => $p->{'svcpart'},
    map { $_ => $p->{$_} } @$fields
  } );
  warn "inserting $class record\n"
    if $DEBUG;
  my $error = $svc_x->insert;

  unless ( $error ) {
    warn "finding inserted record for svcnum ". $svc_x->svcnum. "\n"
      if $DEBUG;
    $svc_x = qsearchs($svc_x->table, { 'svcnum' => $svc_x->svcnum })
  }

  my $return = { 'svc'   => $part_svc->svc,
                 'error' => $error,
                 map { $_ => $svc_x->get($_) } @$return_fields
               };
  warn "_provision returning ". Dumper($return). "\n"
    if $DEBUG;
  return $return;

}

sub part_svc_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,
                                                               } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $svcpart = $p->{'svcpart'};

  my $pkg_svc = qsearchs('pkg_svc', { 'pkgpart' => $cust_pkg->pkgpart,
                                      'svcpart' => $svcpart,           } )
    or return { 'error' => "unknown svcpart $svcpart for pkgnum $pkgnum" };
  my $part_svc = $pkg_svc->part_svc;

  my $conf = new FS::Conf;

  my $ret = {
    'svc'     => $part_svc->svc,
    'svcdb'   => $part_svc->svcdb,
    'pkgnum'  => $pkgnum,
    'svcpart' => $svcpart,
    'custnum' => $custnum,

    'security_phrase' => 0, #XXX !
    'svc_acct_pop'    => [], #XXX !
    'popnum'          => '',
    'init_popstate'   => '',
    'popac'           => '',
    'acstate'         => '',

    'small_custview' =>
      small_custview( $cust_main, $conf->config('countrydefault') ),

  };

  if ($p->{'svcnum'} && $p->{'svcnum'} =~ /^\d+$/ 
                     && $ret->{'svcdb'} eq 'svc_phone') {
        $ret->{'svcnum'} = $p->{'svcnum'};
        my $svc_phone = qsearchs('svc_phone', { svcnum => $p->{'svcnum'} });
        if ( $svc_phone && $svc_phone->cust_svc->cust_pkg->custnum == $custnum ) {
            $ret->{'email'} = $svc_phone->email;
            $ret->{'forwarddst'} = $svc_phone->forwarddst;
        }
  }

  $ret;
}

sub unprovision_svc {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $svcnum = $p->{'svcnum'};

  my $cust_svc = qsearchs('cust_svc', { 'svcnum'  => $svcnum, } )
    or return { 'error' => "unknown svcnum $svcnum" };

  return { 'error' => "Service $svcnum does not belong to customer $custnum" }
    unless $cust_svc->cust_pkg->custnum == $custnum;

  my $conf = new FS::Conf;

  return { 'svc'   => $cust_svc->part_svc->svc,
           'error' => $cust_svc->cancel,
           'small_custview' =>
             small_custview( $cust_main, $conf->config('countrydefault') ),
         };

}

sub myaccount_passwd {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  return { 'error' => "New passwords don't match." }
    if $p->{'new_password'} ne $p->{'new_password2'};

  return { 'error' => 'Enter new password' }
    unless length($p->{'new_password'});

  #my $search = { 'custnum' => $custnum };
  #$search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  $custnum =~ /^(\d+)$/ or die "illegal custnum";
  my $search = " AND custnum = $1";
  $search .= " AND agentnum = ". $session->{'agentnum'} if $context eq 'agent';

  my $svc_acct = qsearchs( {
    'table'     => 'svc_acct',
    'addl_from' => 'LEFT JOIN cust_svc  USING ( svcnum  ) '.
                   'LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                   'LEFT JOIN cust_main USING ( custnum ) ',
    'hashref'   => { 'svcnum' => $p->{'svcnum'}, },
    'extra_sql' => $search, #important
  } )
    or return { 'error' => "Service not found" };

  if ( exists($p->{'old_password'}) ) {
    return { 'error' => "Incorrect password." }
      unless $svc_acct->check_password($p->{'old_password'});
  }

  $svc_acct->_password($p->{'new_password'});
  my $error = $svc_acct->replace();

  my($label, $value) = $svc_acct->cust_svc->label;

  return { 'error' => $error,
           'label' => $label,
           'value' => $value,
         };

}

sub reset_passwd {
  my $p = shift;

  my $conf = new FS::Conf;
  my $verification = $conf->config('selfservice-password_reset_verification')
    or return { 'error' => 'Password resets disabled' };

  my $username = $p->{'username'};

  my $svc_domain = qsearchs('svc_domain', { 'domain' => $p->{'domain'} } )
    or return { 'error' => 'Account not found' };

  my $svc_acct = qsearchs('svc_acct', { 'username' => $p->{'username'},
                                        'domsvc'   => $svc_domain->svcnum  }
                         )
    or return { 'error' => 'Account not found' };

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg
    or return { 'error' => 'Account not found' };

  my $cust_main = $cust_pkg->cust_main;

  my %verify = (
    'paymask' => sub { 
      my( $p, $cust_main ) = @_;
      $cust_main->payby =~ /^(CARD|DCRD|CHEK|DCHK)$/
        && $p->{'paymask'} eq substr($cust_main->paymask, -4)
    },
    'amount'  => sub {
      my( $p, $cust_main ) = @_;
      my $cust_pay = qsearchs({
        'table' => 'cust_pay',
        'hashref' => { 'custnum' => $cust_main->custnum },
        'order_by' => 'ORDER BY _date DESC LIMIT 1',
      })
        or return 0;

      $p->{'amount'} == $cust_pay->paid;
    },
    'zip'     => sub {
      my( $p, $cust_main ) = @_;
      $p->{'zip'} eq $cust_main->zip
        || ( $cust_main->ship_zip && $p->{'zip'} eq $cust_main->ship_zip );
    },
  );

  foreach my $verify ( split(',', $verification) ) {

    &{ $verify{$verify} }( $p, $cust_main )
      or return { 'error' => 'Account not found' };

  }

  #okay, we're verified, now create a unique session

  my $reset_session = {
    'svcnum' => $svc_acct->svcnum,
  };

  my $timeout = '1 hour'; #?

  my $reset_session_id;
  do {
    $reset_session_id = md5_hex(md5_hex(time(). {}. rand(). $$))
  } until ( ! defined _cache->get("reset_passwd_$reset_session_id") ); #just in case

  _cache->set( "reset_passwd_$reset_session_id", $reset_session, $timeout );

  #email it

  my $msgnum = $conf->config('selfservice-password_reset_msgnum', $cust_main->agentnum);
  #die "selfservice-password_reset_msgnum unset" unless $msgnum;
  return { 'error' => "selfservice-password_reset_msgnum unset" } unless $msgnum;
  my $msg_template = qsearchs('msg_template', { msgnum => $msgnum } );
  my $error = $msg_template->send( 'cust_main'     => $cust_main,
                                   'object'        => $svc_acct,
                                   'substitutions' => {
                                     'session_id' => $reset_session_id,
                                   }
                                 );
  if ( $error ) {
    return { 'error' => $error }; #????
  }

  return { 'error' => '' };
}

sub check_reset_passwd {
  my $p = shift;

  my $conf = new FS::Conf;
  my $verification = $conf->config('selfservice-password_reset_verification')
    or return { 'error' => 'Password resets disabled' };

  my $reset_session = _cache->get('reset_passwd_'. $p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $svcnum = $reset_session->{'svcnum'};

  my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $svcnum } )
    or return { 'error' => "Service not found" };

  return { 'error'    => '',
           'username' => $svc_acct->username,
         };

}

sub process_reset_passwd {
  my $p = shift;

  my $conf = new FS::Conf;
  my $verification = $conf->config('selfservice-password_reset_verification')
    or return { 'error' => 'Password resets disabled' };

  return { 'error' => "New passwords don't match." }
    if $p->{'new_password'} ne $p->{'new_password2'};

  return { 'error' => 'Enter new password' }
    unless length($p->{'new_password'});

  my $reset_session = _cache->get('reset_passwd_'. $p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $svcnum = $reset_session->{'svcnum'};

  my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $svcnum } )
    or return { 'error' => "Service not found" };

  $svc_acct->_password($p->{'new_password'});
  my $error = $svc_acct->replace();

  my($label, $value) = $svc_acct->cust_svc->label;

  return { 'error' => $error,
           #'label' => $label,
           #'value' => $value,
         };

}

sub create_ticket {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  warn "$me create_ticket: initializing ticket system\n" if $DEBUG;
  FS::TicketSystem->init();

  my $conf = new FS::Conf;
  my $queue = $p->{'queue'}
              || $conf->config('ticket_system-selfservice_queueid')
              || $conf->config('ticket_system-default_queueid');

  warn "$me create_ticket: creating ticket\n" if $DEBUG;
  my $err_or_ticket = FS::TicketSystem->create_ticket(
    '', #create RT session based on FS CurrentUser (fs_selfservice)
    'queue'   => $queue,
    'custnum' => $custnum,
    'svcnum'  => $session->{'svcnum'},
    map { $_ => $p->{$_} } qw( requestor cc subject message mime_type )
  );

  if ( ref($err_or_ticket) ) {
    warn "$me create_ticket: successful: ". $err_or_ticket->id. "\n"
      if $DEBUG;
    return { 'error'     => '',
             'ticket_id' => $err_or_ticket->id,
           };
  } else {
    warn "$me create_ticket: unsuccessful: $err_or_ticket\n"
      if $DEBUG;
    return { 'error' => $err_or_ticket };
  }


}

sub did_report {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';
 
  return { error => 'requested format not implemented' } 
    unless ($p->{'format'} eq 'csv' || $p->{'format'} eq 'xls');

  my $conf = new FS::Conf;
  my $age_threshold = 0;
  $age_threshold = time() - $conf->config('selfservice-recent-did-age')
    if ($p->{'recentonly'} && $conf->exists('selfservice-recent-did-age'));

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

# does it make more sense to just run one sql query for this instead of all the
# insanity below? would increase performance greately for large data sets?
  my @svc_phone = ();
  foreach my $cust_pkg ( $cust_main->ncancelled_pkgs ) {
	my @part_svc = $cust_pkg->part_svc;
	foreach my $part_svc ( @part_svc ) {
	    if($part_svc->svcdb eq 'svc_phone'){
		my @cust_pkg_svc = @{$part_svc->cust_pkg_svc};
		foreach my $cust_pkg_svc ( @cust_pkg_svc ) {
		    push @svc_phone, $cust_pkg_svc->svc_x
			if $cust_pkg_svc->date_inserted >= $age_threshold;
		}
	    }
	}
  }

  my $csv;
  my $xls;
  my($xls_r,$xls_c) = (0,0);
  my $xls_workbook;
  my $content = '';
  my @fields = qw( countrycode phonenum pin sip_password phone_name );
  if($p->{'format'} eq 'csv') {
    $csv = new Text::CSV_XS { 'always_quote' => 1,
				 'eol'		=> "\n",
				};
    return { 'error' => 'Unable to create CSV' } unless $csv->combine(@fields);
    $content .= $csv->string;
  }
  elsif($p->{'format'} eq 'xls') {
    my $XLS1 = new IO::Scalar \$content;
    $xls_workbook = Spreadsheet::WriteExcel->new($XLS1) 
	or return { 'error' => "Error opening .xls file: $!" };
    $xls = $xls_workbook->add_worksheet('DIDs');
    foreach ( @fields ) {
	$xls->write(0,$xls_c++,$_);
    }
    $xls_r++;
  }

  foreach my $svc_phone ( @svc_phone ) {
    my @cols = map { $svc_phone->$_ } @fields;
    if($p->{'format'} eq 'csv') {
	return { 'error' => 'Unable to create CSV' } 
	    unless $csv->combine(@cols);
	$content .= $csv->string;
    }
    elsif($p->{'format'} eq 'xls') {
	$xls_c = 0;
	foreach ( @cols ) {
	    $xls->write($xls_r,$xls_c++,$_);
	}
	$xls_r++;
    }
  }

  $xls_workbook->close() if $p->{'format'} eq 'xls';
  
  { content => $content, format => $p->{'format'}, };
}

sub get_ticket {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  warn "$me get_ticket: initializing ticket system\n" if $DEBUG;
  FS::TicketSystem->init();
  return { 'error' => 'get_ticket configuration error' }
    if $FS::TicketSystem::system ne 'RT_Internal';

  # check existence and ownership as part of this
  warn "$me get_ticket: fetching ticket\n" if $DEBUG;
  my $rt_session = FS::TicketSystem->session('');
  my $Ticket = FS::TicketSystem->get_ticket_object(
    $rt_session, 
    ticket_id => $p->{'ticket_id'},
    custnum => $custnum
  );
  return { 'error' => 'ticket not found' } if !$Ticket;

  if ( length( $p->{'subject'} || '' ) ) {
    # subject change
    if ( $p->{'subject'} ne $Ticket->Subject ) {
      my ($val, $msg) = $Ticket->SetSubject($p->{'subject'});
      return { 'error' => "unable to set subject: $msg" } if !$val;
    }
  }

  if(length($p->{'reply'})) {
    my @err_or_res = FS::TicketSystem->correspond_ticket(
      $rt_session,
      'ticket_id' => $p->{'ticket_id'},
      'content' => $p->{'reply'},
    );

    return { 'error' => 'unable to reply to ticket' } 
    unless ( $err_or_res[0] != 0 && defined $err_or_res[2] );
  }

  warn "$me get_ticket: getting ticket history\n" if $DEBUG;
  my $err_or_ticket = FS::TicketSystem->get_ticket(
    $rt_session,
    'ticket_id' => $p->{'ticket_id'},
  );

  if ( !ref($err_or_ticket) ) { # there is no way this should ever happen
    warn "$me get_ticket: unsuccessful: $err_or_ticket\n"
      if $DEBUG;
    return { 'error' => $err_or_ticket };
  }

  my @custs = @{$err_or_ticket->{'custs'}};
  my @txns = @{$err_or_ticket->{'txns'}};
  my @filtered_txns;

  # superseded by check in get_ticket_object
  #return { 'error' => 'invalid ticket requested' } 
  #unless grep($_ eq $custnum, @custs);

  foreach my $txn ( @txns ) {
    push @filtered_txns, $txn 
    if ($txn->{'type'} eq 'EmailRecord' 
      || $txn->{'type'} eq 'Correspond'
      || $txn->{'type'} eq 'Create');
  }

  warn "$me get_ticket: successful: \n"
  if $DEBUG;
  return { 'error'     => '',
    'transactions' => \@filtered_txns,
    'ticket_fields' => $err_or_ticket->{'fields'},
    'ticket_id' => $p->{'ticket_id'},
  };
}

sub adjust_ticket_priority {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  warn "$me adjust_ticket_priority: initializing ticket system\n" if $DEBUG;
  FS::TicketSystem->init;
  my $ss_priority = FS::TicketSystem->selfservice_priority;

  return { 'error' => 'adjust_ticket_priority configuration error' }
    if $FS::TicketSystem::system ne 'RT_Internal'
      or !$ss_priority;

  my $values = $p->{'values'}; #hashref, id => priority value
  my %ticket_error;

  foreach my $id (keys %$values) {
    warn "$me adjust_ticket_priority: fetching ticket $id\n" if $DEBUG;
    my $Ticket = FS::TicketSystem->get_ticket_object('',
      'ticket_id' => $id,
      'custnum'   => $custnum,
    );
    if ( !$Ticket ) {
      $ticket_error{$id} = 'ticket not found';
      next;
    }
    
  # RT API stuff--would we gain anything by wrapping this in FS::TicketSystem?
  # We're not going to implement it for RT_External.
    my $old_value = $Ticket->FirstCustomFieldValue($ss_priority);
    my $new_value = $values->{$id};
    next if $old_value eq $new_value;

    warn "$me adjust_ticket_priority: updating ticket $id\n" if $DEBUG;

    # AddCustomFieldValue works fine (replacing any existing value) if it's 
    # a single-valued custom field, which it should be.  If it's not, you're 
    # doing something wrong.
    my ($val, $msg);
    if ( length($new_value) ) {
      ($val, $msg) = $Ticket->AddCustomFieldValue( 
        Field => $ss_priority,
        Value => $new_value,
      );
    }
    else {
      ($val, $msg) = $Ticket->DeleteCustomFieldValue(
        Field => $ss_priority,
        Value => $old_value,
      );
    }

    $ticket_error{$id} = $msg if !$val;
    warn "$me adjust_ticket_priority: $id: $msg\n" if $DEBUG and !$val;
  }
  return { 'error' => '',
           'ticket_error' => \%ticket_error,
           %{ customer_info($p) } # send updated customer info back
         }
}

#--

sub _custoragent_session_custnum {
  my $p = shift;

  my($context, $session, $custnum);
  if ( $p->{'session_id'} ) {

    $context = 'customer';
    $session = _cache->get($p->{'session_id'})
      or return ( 'error' => "Can't resume session" ); #better error message
    $custnum = $session->{'custnum'};

  } elsif ( $p->{'agent_session_id'} ) {

    $context = 'agent';
    my $agent_cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Agent',
    } );
    $session = $agent_cache->get($p->{'agent_session_id'})
      or return ( 'error' => "Can't resume session" ); #better error message
    $custnum = $p->{'custnum'};

  } else {
    $context = 'error';
    return ( 'error' => "Can't resume session" ); #better error message
  }

  ($context, $session, $custnum);

}

1;

