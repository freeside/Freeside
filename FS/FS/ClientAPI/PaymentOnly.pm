package FS::ClientAPI::PaymentOnly;

use 5.008; #require 5.8+ for Time::Local 1.05+
use strict;
use vars qw( $cache $DEBUG $me );
use subs qw( _cache _provision );
use FS::ClientAPI_SessionCache;

use IO::Scalar;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha512_hex);
use Date::Format;
use Time::Duration;
use Time::Local qw(timelocal_nocheck);
use Business::CreditCard 0.35;
use HTML::Entities;
use Text::CSV_XS;
use Spreadsheet::WriteExcel;
use OLE::Storage_Lite;
use FS::UI::Web::small_custview qw(small_custview); #less doh
use FS::UI::Web;
use FS::UI::bytecount qw( display_bytecount );
use FS::Conf;
#use FS::UID qw(dbh);
use FS::Record qw(qsearch qsearchs dbh);
use FS::Msgcat qw(gettext);
use FS::Misc qw(card_types money_pretty);
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
use FS::part_pkg;
use FS::cust_pkg;
use FS::payby;
use FS::acct_rt_transaction;
use FS::msg_template;
use FS::contact;
use FS::cust_contact;
use FS::cust_location;
use FS::cust_payby;

$DEBUG = 0;
$me = '[FS::ClientAPI::PaymentOnly]';

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::PaymentOnly',
             } );
}

sub payment_only_skin_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  #return { 'error' => $session } if $context eq 'error';

  my $agentnum = '';
  if ( $context eq 'customer' && $custnum ) {

    my $sth = dbh->prepare('SELECT agentnum FROM cust_main WHERE custnum = ?')
      or die dbh->errstr;

    $sth->execute($custnum) or die $sth->errstr;

    $agentnum = $sth->fetchrow_arrayref->[0]
      or die "no agentnum for custnum $custnum";

  #} elsif ( $context eq 'agent' ) {
  } elsif ( defined($p->{'agentnum'}) and $p->{'agentnum'} =~ /^(\d+)$/ ) {
    $agentnum = $1;
  }
  $p->{'agentnum'} = $agentnum;

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
        qw( body_bgcolor box_bgcolor stripe1_bgcolor stripe2_bgcolor
            text_color link_color vlink_color hlink_color alink_color
            font title_color title_align title_size menu_bgcolor menu_fontsize
          )
      ),
      'menu_disable' => [ $conf->config('selfservice-menu_disable',$agentnum) ],
      ( map { $_ => $conf->exists("selfservice-$_", $agentnum ) }
        qw( menu_skipblanks menu_skipheadings menu_nounderline no_logo enable_payment_without_balance )
      ),
      ( map { $_ => scalar($conf->config_binary("selfservice-$_", $agentnum)) }
        qw( title_left_image title_right_image
            menu_top_image menu_body_image menu_bottom_image
          )
      ),
      'logo' => scalar($conf->config_binary('logo.png', $agentnum )),
      ( map { $_ => join("\n", $conf->config("selfservice-$_", $agentnum ) ) }
        qw( head body_header body_footer company_address ) ),
      'money_char' => $conf->config("money_char") || '$',
      'menu' => 'payment_only_payment.php Make Payment

                 payment_only_logout.php Logout
                ',
    };

    _cache->set("skin_info_cache_agent$agentnum", $skin_info_cache_agent);

  }

  #{ %$skin_info_cache_agent };
  $skin_info_cache_agent;

}

sub ip_login {
  my $p = shift;

  my $conf = new FS::Conf;

  my $svc_x = '';
  my $session = {};
  my $cust_main;

  return { error => 'MAC address empty '.$p->{'mac'} }
    unless $p->{'mac'};

      my $mac_address = $p->{'mac'};
      $mac_address =~ s/[\:\,\-\. ]//g;
      $mac_address =~ tr/[a-z]/[A-Z/;

      my $svc_broadband = qsearchs( 'svc_broadband', { 'mac_addr' => $mac_address } );
      return { error => 'MAC address not found $mac_address '.$p->{'mac'} }
        unless $svc_broadband;
      $svc_x = $svc_broadband;

  if ( $svc_x ) {

    $session->{'svcnum'} = $svc_x->svcnum;

    my $cust_svc = $svc_x->cust_svc;
    my $cust_pkg = $cust_svc->cust_pkg;
    if ( $cust_pkg ) {
      $cust_main = $cust_pkg->cust_main;
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

  }
  else {
    return { error => "No Service Found with Mac Address ".$p->{'mac'} };
  }

  ## get account information
  my ($cust_payby_card) = $cust_main->cust_payby('CARD', 'DCRD');
  if ($cust_payby_card) {
    $session->{'CARD'} = $cust_payby_card->custpaybynum;
  }
  my ($cust_payby_check) = $cust_main->cust_payby('CHEK', 'DCHK');
  if ($cust_payby_check) {
    $session->{'CHEK'} = $cust_payby_check->custpaybynum;
  }

  my $session_id;
  do {
    $session_id = sha512_hex(time(). {}. rand(). $$)
  } until ( ! defined _cache->get($session_id) ); #just in case

  my $timeout = $conf->config('selfservice-session_timeout') || '1 hour';
  _cache->set( $session_id, $session, $timeout );

  return { 'error'      => '',
           'session_id' => $session_id,
           %$session,
         };
}

sub ip_logout {
  my $p = shift;
  my $skin_info = skin_info($p);
  if ( $p->{'session_id'} ) {
    _cache->remove($p->{'session_id'});
    return { %$skin_info, 'error' => '' };
  } else {
    return { %$skin_info, 'error' => "Can't resume session" }; #better error message
  }
}

sub get_mac_address {
  my $p = shift;

## access radius exports acct tables to get mac
  my @part_export = ();
  @part_export = (
    qsearch( 'part_export', { 'exporttype' => 'sqlradius' } ),
    qsearch( 'part_export', { 'exporttype' => 'sqlradius_withdomain' } ),
    qsearch( 'part_export', { 'exporttype' => 'broadband_sqlradius' } ),
  );

  my @sessions;
  foreach my $part_export (@part_export) {
    push @sessions, ( @{ $part_export->usage_sessions( {
      'ip' => $p->{'ip'},
      'session_status' => 'open',
    } ) } );
  }

  return { 'mac_address' => $sessions[0]->{'callingstationid'}, };
}

sub payment_only_payment_info {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session today" }; #better error message

  my $custnum = $session->{'custnum'};
  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $payment_info = {
    'balance' => $cust_main->balance,
  };

  #doubleclick protection
  my $_date = time;
  $payment_info->{'payunique'} = "webui-PaymentOnly-$_date-$$-". rand() * 2**32; #new
  $payment_info->{'paybatch'} = $payment_info->{'payunique'};  #back compat

  if ($session->{'CARD'}) {
    my $card_payby = qsearchs('cust_payby', { 'custpaybynum' => $session->{'CARD'} });
    if ($card_payby) {
       $payment_info->{'CARD'} = $session->{'CARD'};
       $payment_info->{'card_mask'} = $card_payby->paymask;
       $payment_info->{'card_type'} = $card_payby->paycardtype;
    }
  }

  if ($session->{'CHEK'}) {
    my $check_payby = qsearchs('cust_payby', { 'custpaybynum' => $session->{'CHEK'} });
    if ($check_payby) {
       my ($payaccount, $payaba) = split /\@/, $check_payby->paymask;
       $payment_info->{'CHEK'} = $session->{'CHEK'};
       $payment_info->{'check_mask'} = $payaccount;
       $payment_info->{'check_type'} = $check_payby->paytype;
    }
  }

  return $payment_info;

}

sub payment_only_process_payment {
  my $p = shift;

  my $payment_info = _validate_payment($p);
  return $payment_info if $payment_info->{'error'};

  FS::ClientAPI::MyAccount::do_process_payment($payment_info);

  #return;
}

sub _validate_payment {
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

  #false laziness w/tr-amount_fee.html, but we don't want selfservice users
  #changing the hidden form values
  my $conf = new FS::Conf;
  my $fee_display = $conf->config('selfservice_process-display') || 'add';
  my $fee_pkgpart = $conf->config('selfservice_process-pkgpart', $cust_main->agentnum);
  my $fee_skip_first = $conf->exists('selfservice_process-skip_first');
  if ( $fee_display eq 'add'
         and $fee_pkgpart
         and ! $fee_skip_first || scalar($cust_main->cust_pay)
     )
  {
    my $fee_pkg = qsearchs('part_pkg', { pkgpart=>$fee_pkgpart } );
    $amount = sprintf('%.2f', $amount + $fee_pkg->option('setup_fee') );
  }

  #$p->{'payby'} ||= 'CARD';
  $p->{'payby'} =~ /^([A-Z]{4})$/
    or return { 'error' => "illegal_payby " . $p->{'payby'} };
  my $payby = $1;

  ## get info from custpaybynum.
  my $custpayby = qsearchs('cust_payby', { custpaybynum => $session->{$p->{'payby'}} } )
    or return { 'error' => 'No payment information found' };

  $p->{'discount_term'} =~ /^\s*(\d*)\s*$/
    or return { 'error' => gettext('illegal_discount_term'). ': '. $p->{'discount_term'} };
  my $discount_term = $1;

  $p->{'payunique'} =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
    or return { 'error' => gettext('illegal_text'). " payunique: ". $p->{'payunique'} };
  my $payunique = $1;

  $p->{'paybatch'} =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
    or return { 'error' => gettext('illegal_text'). " paybatch: ". $p->{'paybatch'} };
  my $paybatch = $1;

  $payunique = $paybatch if ! length($payunique) && length($paybatch);
  my $payname = $custpayby->payname;

  #false laziness w/process/payment.cgi
  my $payinfo = $custpayby->payinfo;
  my $onfile = 1;
  my $paycvv = '';
  my $replace_cust_payby;

  if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {

    my ($payinfo1, $payinfo2) = split /\@/, $payinfo;
    $payinfo1 =~ /^([\dx]+)$/
      or return { 'error' => "illegal account number " };
     $payinfo2 =~ /^([\dx]+)$/
      or return { 'error' => "illegal ABA/routing number " }; 

  } elsif ( $payby eq 'CARD' || $payby eq 'DCRD' ) {

    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,19}|\d{8,9})$/
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    $payinfo = $1;

    validate($payinfo)
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    return { 'error' => gettext('unknown_card_type') }
      if !$cust_main->tokenized($payinfo) && cardtype($payinfo) eq "Unknown";

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
    } elsif ( $conf->exists('selfservice-onfile_require_cvv') ) {
      return { 'error' => 'CVV2 is required' };
    } elsif ( !$onfile && $conf->exists('selfservice-require_cvv') ) {
      return { 'error' => 'CVV2 is required' };
    }
  
  } else {
    die "unknown payby $payby";
  }

  $p->{$_} = $cust_main->bill_location->get($_) 
    for qw(address1 address2 city state zip);

  my %payby2fields = (
    'CARD' => [ qw( paystart_month paystart_year payissue payip
                    address1 address2 city state zip country    ) ],
    'CHEK' => [ qw( ss paytype paystate stateid stateid_state payip ) ],
  );

  my $card_type = '';
  $card_type = cardtype($payinfo) if $payby eq 'CARD';

  my ($year, $month, $day) = split /-/, $custpayby->{Hash}->{paydate};

  my $return = { 
    'cust_main'      => $cust_main, #XXX or just custnum??
    'amount'         => sprintf('%.2f', $amount),
    'payby'          => $payby,
    'payinfo'        => $payinfo,
    'paymask'        => $custpayby->paymask,
    'card_type'      => $card_type,
    'paydate'        => $custpayby->paydate,
    'paydate_pretty' => $month. ' / '. $year,
    'month'          => $month,
    'year'           => $year,
    'payname'        => $custpayby->{HASH}->{payname},
    'payunique'      => $payunique,
    'paybatch'       => $paybatch,
    'paycvv'         => $paycvv,
    'payname'        => $payname,
    'discount_term'  => $discount_term,
    'pkgnum'         => $session->{'pkgnum'},
    map { $_ => $p->{$_} } ( @{ $payby2fields{$payby} } )
  };

  return $return;

}

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