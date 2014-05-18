#!/usr/bin/perl -w

use strict;
use vars qw($DEBUG $cgi $session_id $form_max $template_dir);
use subs qw(do_template);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use Text::Template;
use HTML::Entities;
use Date::Format;
use Date::Parse 'str2time';
use Number::Format 1.50;
use FS::SelfService qw(
  access_info login_info login customer_info edit_info invoice
  payment_info process_payment realtime_collect process_prepay
  list_pkgs order_pkg signup_info order_recharge
  part_svc_info provision_acct provision_external provision_phone
  unprovision_svc change_pkg suspend_pkg domainselector
  list_svcs list_svc_usage list_cdr_usage list_support_usage
  myaccount_passwd list_invoices create_ticket get_ticket did_report
  adjust_ticket_priority
  mason_comp port_graph
  start_thirdparty finish_thirdparty
  reset_passwd check_reset_passwd process_reset_passwd
);

$template_dir = '.';

$DEBUG = 0;

$form_max = 255;

$cgi = new CGI;

#order|pw_list XXX ???
my @actions = ( qw(
  myaccount
  tktcreate
  tktview
  ticket_priority
  didreport
  invoices
  view_invoice
  make_payment
  make_ach_payment
  make_term_payment
  make_thirdparty_payment
  post_thirdparty_payment
  finish_thirdparty_payment
  cancel_thirdparty_payment
  payment_results
  ach_payment_results
  recharge_prepay
  recharge_results
  logout
  change_bill
  change_ship
  change_pay
  process_change_bill
  process_change_ship
  process_change_pay
  customer_order_pkg
  process_order_pkg
  customer_change_pkg
  process_change_pkg
  process_order_recharge
  provision
  provision_svc
  process_svc_acct
  process_svc_phone
  process_svc_external
  delete_svc
  view_usage
  view_usage_details
  view_cdr_details
  view_support_details
  view_port_graph
  real_port_graph
  change_password
  process_change_password
  customer_suspend_pkg
  process_suspend_pkg
));

my @nologin_actions = (qw(
  forgot_password
  do_forgot_password
  process_forgot_password
  do_process_forgot_password
));
push @actions, @nologin_actions;
my %nologin_actions = map { $_=>1 } @nologin_actions;

my $action = 'myaccount'; # sensible default
if ( $cgi->param('action') =~ /^(\w+)$/ ) {
  if (grep {$_ eq $1} @actions) {
    $action = $1;
  } else {
    warn "WARNING: unrecognized action '$1'\n";
  }
}

unless ( $nologin_actions{$action} ) {

  my %cookies = CGI::Cookie->fetch;

  my $login_rv = {};

  if ( exists($cookies{'session'}) ) {

    $session_id = $cookies{'session'}->value;

    if ( $session_id eq 'login' ) {
      # then we've just come back from the login page

      $cgi->param('password') =~ /^(.{0,$form_max})$/;
      my $password = $1;

      if ( $cgi->param('email') =~ /^\s*([a-z0-9_\-\.\@]{1,$form_max})\s*$/i ) {

        my $email = $1;
        $login_rv = login(
          'email'    => $email,
          'password' => $password
        );
        $session_id = $login_rv->{'session_id'};

      } else {

        $cgi->param('username') =~ /^\s*([a-z0-9_\-\.\&]{0,$form_max})\s*$/i;
        my $username = $1;

        $cgi->param('domain') =~ /^\s*([\w\-\.]{0,$form_max})\s*$/;
        my $domain = $1;

        if ( $username and $domain and $password ) {

          # authenticate
          $login_rv = login(
            'username' => $username,
            'domain'   => $domain,
            'password' => $password,
          );
          $session_id = $login_rv->{'session_id'};

        } elsif ( $username or $domain or $password ) {
        
          my $error = 'Illegal '; #XXX localization...
          my $count = 0;
          if ( !$username ) {
            $error .= 'username';
            $count++;
          }
          if ( !$domain )  {
            $error .= ', ' if $count;
            $error .= 'domain';
            $count++;
          }
          if ( !$password ) {
            $error .= ', ' if $count;
            $error .= 'and ' if $count > 1;
            $error .= 'password';
            $count++;
          }
          $error .= '.';
          $login_rv = {
            'username'  => $username,
            'domain'    => $domain,
            'password'  => $password,
            'error'     => $error,
          };
          $session_id = undef; # attempt login again

        }

      } # else there was no input, so show no error message

    } # else session_id ne 'login'

  } # else there is no session cookie

  if ( !$session_id ) {
    # show the login page
    $session_id = 'login'; # set state
    my $login_info = login_info( 'agentnum' => scalar($cgi->param('agentnum')) );

    do_template('login', { %$login_rv, %$login_info });
    exit;
  }

  # at this point $session_id is a real session

}

warn "calling $action sub\n"
  if $DEBUG;
$FS::SelfService::DEBUG = $DEBUG;
my $result = eval "&$action();";
die $@ if $@;

warn Dumper($result) if $DEBUG;

if ( $result->{error} && ( $result->{error} eq "Can't resume session"
  || $result->{error} eq "Expired session") ) { #ick

  $session_id = 'login';
  my $login_info = login_info( 'agentnum' => scalar($cgi->param('agentnum')) );
  do_template('login', $login_info);
  exit;
}

#warn $result->{'open_invoices'};
#warn scalar(@{$result->{'open_invoices'}});

warn "processing template $action\n"
  if $DEBUG;
do_template($action, {
  'session_id' => $session_id,
  'action'     => $action, #so the menu knows what tab we're on...
  #%{ payment_info( 'session_id' => $session_id ) },  # cust_paybys for the menu
  %{$result}
});

#--

use Data::Dumper;
sub myaccount { 
  customer_info( 'session_id' => $session_id ); 
}

sub change_bill { my $payment_info =
                    payment_info( 'session_id' => $session_id );
                  return $payment_info if ( $payment_info->{'error'} );
                  my $customer_info =
                    customer_info( 'session_id' => $session_id );
                  return { 
                    %$payment_info,
                    %$customer_info,
                  };
                }
sub change_ship { change_bill(@_); }
sub change_pay { change_bill(@_); }

sub _process_change_info { 
  my ($erroraction, @fields) = @_;

  my $results = '';

  $results ||= edit_info (
    'session_id' => $session_id,
    map { ($_ => $cgi->param($_)) } grep { defined($cgi->param($_)) } @fields,
  );


  if ( $results->{'error'} ) {
    no strict 'refs';
    $action = $erroraction;
    return {
      $cgi->Vars,
      %{&$action()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }
}

sub process_change_bill {
        _process_change_info( 'change_bill', 
          qw( first last company address1 address2 city state
              county zip country daytime night fax )
        );
}

sub process_change_ship {
        my @list = map { "ship_$_" }
                     qw( first last company address1 address2 city state
                         county zip country daytime night fax 
                       );
        if ($cgi->param('same') eq 'Y') {
          foreach (@list) { $cgi->param($_, '') }
        }

        _process_change_info( 'change_ship', @list );
}

sub process_change_pay {
        my $postal = $cgi->param( 'postal_invoicing' );
        my $payby  = $cgi->param( 'payby' );
        my @list =
          qw( payby payinfo payinfo1 payinfo2 month year payname
              address1 address2 city county state zip country auto paytype
              paystate ss stateid stateid_state invoicing_list
            );
        push @list, 'postal_invoicing' if $postal;
        unless (    $payby ne 'BILL'
                 || $postal
                 || $cgi->param( 'invoicing_list' )
               )
        {
          $action = 'change_pay';
          return {
            %{&change_pay()},
            $cgi->Vars,
            'error' => '<FONT COLOR="#FF0000">Postal or email required.</FONT>',
          };
        }
        _process_change_info( 'change_pay', @list );
}

sub view_invoice {

  $cgi->param('invnum') =~ /^(\d+)$/ or die "illegal invnum";
  my $invnum = $1;

  invoice( 'session_id' => $session_id,
           'invnum'     => $invnum,
         );

}

sub invoices {
  list_invoices( 'session_id' => $session_id, );
}

sub tktcreate {
  my $customer_info = customer_info( 'session_id' => $session_id );
  return $customer_info if ( $customer_info->{'error'} );

  my $requestor = "";
  if ( $customer_info->{'invoicing_list'} ) {
    my @requestor = split( /\s*\,\s*/, $customer_info->{'invoicing_list'} );
    $requestor = $requestor[0] if scalar(@requestor);
  }

  return { 'requestor' => $requestor }
    unless ($cgi->param('subject') && $cgi->param('message') &&
	length($cgi->param('subject')) && length($cgi->param('message')));
    
 create_ticket(	'session_id' => $session_id,
			'subject' => $cgi->param('subject'),
			'message' => $cgi->param('message'), 
			'requestor' => $requestor,
	    );
}

sub tktview {
 get_ticket(	'session_id' => $session_id,
		'ticket_id' => ($cgi->param('ticket_id') || ''),
                'subject'   => ($cgi->param('subject') || ''),
		'reply'     => ($cgi->param('reply') || ''),
	    );
}

sub ticket_priority {
  my %values;
  foreach ( $cgi->param ) {
    if ( /^ticket(\d+)$/ ) {
      # a 'ticket1001' param implies the existence of a 'priority1001' param
      # but if that's empty, we need to send it as empty rather than forget
      # it.
      $values{$1} = $cgi->param("priority$1") || '';
    }
  }
  $action = 'myaccount';
  # this returns an updated customer_info for myaccount
  adjust_ticket_priority( 'session_id' => $session_id,
                          'values'     => \%values );
}

sub customer_order_pkg {
  my $init_data = signup_info( 'customer_session_id' => $session_id );
  return $init_data if ( $init_data->{'error'} );

  my $customer_info = customer_info( 'session_id' => $session_id );
  return $customer_info if ( $customer_info->{'error'} );

  my $pkgselect = mason_comp(
    'session_id' => $session_id,
    'comp'       => '/edit/cust_main/first_pkg/select-part_pkg.html',
    'args'       => [ 'password_verify' => 1,
                      'onchange'        => 'enable_order_pkg()',
                      'relurls'         => 1,
                      'empty_label'     => 'Select package',
                    ],
  );

  $pkgselect = $pkgselect->{'error'} || $pkgselect->{'output'};

  return {
    ( map { $_ => $init_data->{$_} }
          qw( part_pkg security_phrase svc_acct_pop ),
    ),
    %$customer_info,
    'pkg_selector' => $pkgselect,
  };
}

sub customer_change_pkg {
  my $init_data = signup_info( 'customer_session_id' => $session_id );
  return $init_data if ( $init_data->{'error'} );

  my $customer_info = customer_info( 'session_id' => $session_id );
  return $customer_info if ( $customer_info->{'error'} );

  return {
    ( map { $_ => $init_data->{$_} }
          qw( part_pkg security_phrase svc_acct_pop ),
    ),
    ( map { $_ => $cgi->param($_) }
        qw( pkgnum pkg )
    ),
    %$customer_info,
  };
}

sub process_order_pkg {

  my $results = '';

  my @params = (qw( custnum pkgpart ));
  my $svcdb = '';
  if ( $cgi->param('pkgpart_svcpart') =~ /^(\d+)_(\d+)$/ ) {
    $cgi->param('pkgpart', $1);
    $cgi->param('svcpart', $2);
    push @params, 'svcpart';
    $svcdb = $cgi->param('svcdb');
    push @params, 'domsvc' if $svcdb eq 'svc_acct';
  } else {
    $svcdb = 'svc_acct';
  }

  if ( $svcdb eq 'svc_acct' ) {

    push @params, qw( username _password _password2 sec_phrase popnum );

    unless ( length($cgi->param('_password')) ) {
      my $init_data = signup_info( 'customer_session_id' => $session_id );
      $results = { 'error' => $init_data->{msgcat}{empty_password} };
      $results = { 'error' => $init_data->{error} } if($init_data->{error});
    }
    if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
      my $init_data = signup_info( 'customer_session_id' => $session_id );
      $results = { 'error' => $init_data->{msgcat}{passwords_dont_match} };
      $results = { 'error' => $init_data->{error} } if($init_data->{error});
      $cgi->param('_password', '');
      $cgi->param('_password2', '');
    }

  } elsif ( $svcdb eq 'svc_phone' ) {

    push @params, qw( phonenum sip_password pin phone_name );

  } else {
    die "$svcdb not handled on process_order_pkg yet";
  }

  $results ||= order_pkg (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } @params
  );


  if ( $results->{'error'} ) {
    $action = 'customer_order_pkg';
    return {
      $cgi->Vars,
      %{customer_order_pkg()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub process_change_pkg {

  my $results = '';

  $results ||= change_pkg (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( pkgpart pkgnum )
  );


  if ( $results->{'error'} ) {
    $action = 'customer_change_pkg';
    return {
      $cgi->Vars,
      %{customer_change_pkg()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub process_suspend_pkg {
  my $results = '';
  $results = suspend_pkg (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } 
      qw( pkgnum )
    );
  if ( $results->{'error'} ) {
    $action = 'provision';
    return {
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    }
  }
  else {
    return $results;
  }
}

sub process_order_recharge {

  my $results = '';

  $results ||= order_recharge (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( svcnum )
  );


  if ( $results->{'error'} ) {
    $action = 'view_usage';
    if ($results->{'error'} eq '_decline') {
      $results->{'error'} = "There has been an error processing your account.  Please contact customer support."
    }
    return {
      $cgi->Vars,
      %{view_usage()},
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    return $results;
  }

}

sub make_payment {

  my $payment_info = payment_info( 'session_id' => $session_id );

  my $tr_amount_fee = mason_comp(
    'session_id' => $session_id,
    'comp'       => '/elements/tr-amount_fee.html',
    'args'       => [ 'amount' => $payment_info->{'balance'},
                    ],
  );

  $tr_amount_fee = $tr_amount_fee->{'error'} || $tr_amount_fee->{'output'};

  $payment_info->{'tr_amount_fee'} = $tr_amount_fee;

  $payment_info;
}

sub payment_results {

  use Business::CreditCard 0.30;

  #we should only do basic checking here for DoS attacks and things
  #that couldn't be constructed by the web form...  let process_payment() do
  #the rest, it gives better error messages

  $cgi->param('amount') =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or die "Illegal amount: ". $cgi->param('amount'); #!!!
  my $amount = $1;

  my $payinfo = $cgi->param('payinfo');
  $payinfo =~ s/[^\dx]//g;
  $payinfo =~ /^([\dx]{13,16}|[\dx]{8,9})$/
    #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    or die "illegal card"; #!!!
  $payinfo = $1;
  unless ( $payinfo =~ /x/ ) {
    validate($payinfo)
      #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
      or die "invalid card"; #!!!
  }

  if ( $cgi->param('card_type') ) {
    cardtype($payinfo) eq $cgi->param('card_type')
      #or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
      or die "not a ". $cgi->param('card_type');
  }

  $cgi->param('paycvv') =~ /^\s*(.{0,4})\s*$/ or die "illegal CVV2";
  my $paycvv = $1;

  $cgi->param('month') =~ /^(\d{2})$/ or die "illegal month";
  my $month = $1;
  $cgi->param('year') =~ /^(\d{4})$/ or die "illegal year";
  my $year = $1;

  $cgi->param('payname') =~ /^(.{0,80})$/ or die "illegal payname";
  my $payname = $1;

  $cgi->param('address1') =~ /^(.{0,80})$/ or die "illegal address1";
  my $address1 = $1;

  $cgi->param('address2') =~ /^(.{0,80})$/ or die "illegal address2";
  my $address2 = $1;

  $cgi->param('city') =~ /^(.{0,80})$/ or die "illegal city";
  my $city = $1;

  $cgi->param('state') =~ /^(.{0,80})$/ or die "illegal state";
  my $state = $1;

  $cgi->param('zip') =~ /^(.{0,10})$/ or die "illegal zip";
  my $zip = $1;

  $cgi->param('country') =~ /^(.{0,2})$/ or die "illegal country";
  my $country = $1;

  my $save = 0;
  $save = 1 if $cgi->param('save');

  my $auto = 0;
  $auto = 1 if $cgi->param('auto');

  $cgi->param('paybatch') =~ /^([\w\-\.]+)$/ or die "illegal paybatch";
  my $paybatch = $1;

  $cgi->param('discount_term') =~ /^(\d*)$/ or die "illegal discount_term";
  my $discount_term = $1;


  process_payment(
    'session_id' => $session_id,
    'payby'      => 'CARD',
    'amount'     => $amount,
    'payinfo'    => $payinfo,
    'paycvv'     => $paycvv,
    'month'      => $month,
    'year'       => $year,
    'payname'    => $payname,
    'address1'   => $address1,
    'address2'   => $address2,
    'city'       => $city,
    'state'      => $state,
    'zip'        => $zip,
    'country'    => $country,
    'save'       => $save,
    'auto'       => $auto,
    'paybatch'   => $paybatch,
    'discount_term' => $discount_term,
  );

}

sub make_ach_payment {
  payment_info( 'session_id' => $session_id );
}

sub ach_payment_results {

  #we should only do basic checking here for DoS attacks and things
  #that couldn't be constructed by the web form...  let process_payment() do
  #the rest, it gives better error messages

  $cgi->param('amount') =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or die "illegal amount"; #!!!
  my $amount = $1;

  my $payinfo1 = $cgi->param('payinfo1');
  $payinfo1 =~ s/[^\dx]//g;
  $payinfo1 =~ /^([\dx]+)$/
    or die "illegal account"; #!!!
  $payinfo1 = $1;

  my $payinfo2 = $cgi->param('payinfo2');
  $payinfo2 =~ s/[^\dx]//g;
  $payinfo2 =~ /^([\dx]+)$/
    or die "illegal ABA/routing code"; #!!!
  $payinfo2 = $1;

  $cgi->param('payname') =~ /^(.{0,80})$/ or die "illegal payname";
  my $payname = $1;

  $cgi->param('paystate') =~ /^(.{0,2})$/ or die "illegal paystate";
  my $paystate = $1;

  $cgi->param('paytype') =~ /^(.{0,80})$/ or die "illegal paytype";
  my $paytype = $1;

  $cgi->param('ss') =~ /^(.{0,80})$/ or die "illegal ss";
  my $ss = $1;

  $cgi->param('stateid') =~ /^(.{0,80})$/ or die "illegal stateid";
  my $stateid = $1;

  $cgi->param('stateid_state') =~ /^(.{0,2})$/ or die "illegal stateid_state";
  my $stateid_state = $1;

  my $save = 0;
  $save = 1 if $cgi->param('save');

  my $auto = 0;
  $auto = 1 if $cgi->param('auto');

  $cgi->param('paybatch') =~ /^([\w\-\.]+)$/ or die "illegal paybatch";
  my $paybatch = $1;

  process_payment(
    'session_id' => $session_id,
    'payby'      => 'CHEK',
    'amount'     => $amount,
    'payinfo1'   => $payinfo1,
    'payinfo2'   => $payinfo2,
    'month'      => '12',
    'year'       => '2037',
    'payname'    => $payname,
    'paytype'    => $paytype,
    'paystate'   => $paystate,
    'ss'         => $ss,
    'stateid'    => $stateid,
    'stateid_state' => $stateid_state,
    'save'       => $save,
    'auto'       => $auto,
    'paybatch'   => $paybatch,
  );

}

sub make_thirdparty_payment {
  my $payment_info = payment_info('session_id' => $session_id);
  $cgi->param('payby_method') =~ /^(CC|ECHECK|PAYPAL)$/
    or die "illegal payby method";
  $payment_info->{'payby_method'} = $1;
  $payment_info->{'error'} = $cgi->param('error');

  $payment_info;
}

sub post_thirdparty_payment {
  $cgi->param('payby_method') =~ /^(CC|ECHECK|PAYPAL)$/
    or die "illegal payby method";
  my $method = $1;
  $cgi->param('amount') =~ /^(\d+(\.\d*)?)$/
    or die "illegal amount";
  my $amount = $1;
  my $result = start_thirdparty(
    'session_id' => $session_id,
    'method' => $method, 
    'amount' => $amount,
  );
  if ( $result->{error} ) {
    $cgi->param('action', 'make_thirdparty_payment');
    $cgi->param('error', $result->{error});
    print $cgi->redirect( $cgi->self_url );
    exit;
  }

  $result;
}

sub finish_thirdparty_payment {
  my %param = $cgi->Vars;
  finish_thirdparty( 'session_id' => $session_id, %param );
  # result contains either 'error' => error message, or the payment details
}

sub cancel_thirdparty_payment {
  $action = 'make_thirdparty_payment';
  finish_thirdparty( 'session_id' => $session_id, '_cancel' => 1 );
}

sub make_term_payment {
  $cgi->param('amount') =~ /^(\d+\.\d{2})$/
    or die "illegal payment amount";
  my $balance = $1;
  $cgi->param('discount_term') =~ /^(\d+)$/
    or die "illegal discount term";
  my $discount_term = $1;
  $action = 'make_payment';
  ({ %{payment_info( 'session_id' => $session_id )},
    'balance' => $balance,
    'discount_term' => $discount_term,
  })
}

sub recharge_prepay {
  customer_info( 'session_id' => $session_id );
}

sub recharge_results {

  my $prepaid_cardnum = $cgi->param('prepaid_cardnum');
  $prepaid_cardnum =~ s/\W//g;
  $prepaid_cardnum =~ /^(\w*)$/ or die "illegal prepaid card number";
  $prepaid_cardnum = $1;

  process_prepay ( 'session_id'     => $session_id,
                   'prepaid_cardnum' => $prepaid_cardnum,
                 );
}

sub logout {
  FS::SelfService::logout( 'session_id' => $session_id );
}

sub didreport {
  my $result = did_report( 'session_id' => $session_id, 
	    'format' => $cgi->param('type'),
	    'recentonly' => $cgi->param('recentonly'),
	);
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};
  $result;
}

sub provision {
  my $result = list_pkgs( 'session_id' => $session_id );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};
  $result->{'pkgpart'} = $cgi->param('pkgpart') if $cgi->param('pkgpart');
  $result->{'filter'} = $cgi->param('filter') if $cgi->param('filter');
  $result;
}

sub provision_svc {

  my $result = part_svc_info(
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart svcnum ),
  );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};

  $result->{'svcdb'} =~ /^svc_(.*)$/
    #or return { 'error' => 'Unknown svcdb '. $result->{'svcdb'} };
    or die 'Unknown svcdb '. $result->{'svcdb'};
  $action .= "_$1";

  $result->{'numavail'} = $cgi->param('numavail');
  $result->{'lnp'} = $cgi->param('lnp');

  $result;
}

sub process_svc_phone {
    my @bulkdid = $cgi->param('bulkdid');
    my $phonenum = $cgi->param('phonenum');
    my $lnp = $cgi->param('lnp');

    my $result;
    if($lnp) {
	$result = provision_phone (
	    'session_id' => $session_id,
	    'countrycode' => '1',
	     map { $_ => $cgi->param($_) } qw( pkgnum svcpart phonenum 
		lnp_desired_due_date lnp_other_provider 
		lnp_other_provider_account )
	);
    } else {
	$result = provision_phone (
	    'session_id' => $session_id,
	    'bulkdid' => [ @bulkdid ],
	    'countrycode' => '1',
	     map { $_ => $cgi->param($_) } qw( pkgnum svcpart phonenum svcnum email forwarddst )
	);
    }

    if ( exists $result->{'error'} && $result->{'error'} ) { 
	$action = 'provision_svc_phone';
	return {
	  $cgi->Vars,
	  %{ part_svc_info( 'session_id' => $session_id,
                        map { $_ => $cgi->param($_) } qw( pkgnum svcpart svcnum )
	      )
	  },
	  'error' => $result->{'error'},
	};
  }

  $result;
}

sub process_svc_acct {

  my $result = provision_acct (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw(
      pkgnum svcpart username domsvc _password _password2 sec_phrase popnum )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 
    #warn "$result $result->{'error'}"; 
    $action = 'provision_svc_acct';
    return {
      $cgi->Vars,
      %{ part_svc_info( 'session_id' => $session_id,
                        map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
                      )
      },
      'error' => $result->{'error'},
    };
  } else {
    #warn "$result $result->{'error'}"; 
    return $result;
  }

}

sub process_svc_external {
  provision_external (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
  );
}

sub delete_svc {
  unprovision_svc(
    'session_id' => $session_id,
    'svcnum'     => $cgi->param('svcnum'),
  );
}

sub view_usage {
  list_svcs(
    'session_id'  => $session_id,
    'svcdb'       => [ 'svc_acct', 'svc_phone', 'svc_port', ],
    'ncancelled'  => 1,
  );
}

sub real_port_graph {
    my $svcnum = $cgi->param('svcnum');
    my $res = port_graph(
	    'session_id'  => $session_id,
	    'svcnum'      => $svcnum,
	    'beginning'	  => str2time($cgi->param('start')." 00:00:00"),
	    'ending'	  => str2time($cgi->param('end')  ." 23:59:59"),
	    );
    my @usage = @{$res->{'usage'}};
    my $png = $usage[0]->{'png'};
    { 'content' => $png, 'format' => 'png' };
}

sub view_port_graph {
    my $svcnum = $cgi->param('svcnum');
    { 'svcnum' => $svcnum,
      'start' => $cgi->param($svcnum.'_start'),
      'end' => $cgi->param($svcnum.'_end'),
    }
}

sub view_usage_details {
      list_svc_usage(
	'session_id'  => $session_id,
	'svcnum'      => $cgi->param('svcnum'),
	'beginning'   => $cgi->param('beginning') || '',
	'ending'      => $cgi->param('ending') || '',
      );
}

sub view_cdr_details {
  list_cdr_usage(
    'session_id'  => $session_id,
    'svcnum'      => $cgi->param('svcnum'),
    'beginning'   => $cgi->param('beginning') || '',
    'ending'      => $cgi->param('ending') || '',
    'inbound'     => $cgi->param('inbound') || 0,
  );
}

sub view_support_details {
  list_support_usage(
    'session_id'  => $session_id,
    'svcnum'      => $cgi->param('svcnum'),
    'beginning'   => $cgi->param('beginning') || '',
    'ending'      => $cgi->param('ending') || '',
  );
}

sub change_password {
  list_svcs(
    'session_id' => $session_id,
    'svcdb'      => 'svc_acct',
  );
};

sub process_change_password {

  my $result = myaccount_passwd(
    'session_id'    => $session_id,
    map { $_ => $cgi->param($_) } qw( svcnum new_password new_password2 )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 

    $action = 'change_password';
    return {
      $cgi->Vars,
      %{ list_svcs( 'session_id' => $session_id,
                    'svcdb'      => 'svc_acct',
                  )
       },
      #'svcnum' => $cgi->param('svcnum'),
      'error'  => $result->{'error'}
    };

 } else {

   return $result;

 }

}

sub forgot_password {
  login_info( 'agentnum' => scalar($cgi->param('agentnum')) );
}

sub do_forgot_password {
  reset_passwd(
    map { $_ => scalar($cgi->param($_)) }
      qw( agentnum email username domain )
  );
}

sub process_forgot_password {
  check_reset_passwd(
    map { $_ => scalar($cgi->param($_)) }
      qw( session_id )
  );
}

sub do_process_forgot_password {
  process_reset_passwd(
    map { $_ => scalar($cgi->param($_)) }
      qw( session_id new_password new_password2 )
  );
}

#--

sub do_template {
  my $name = shift;
  my $fill_in = shift;

  $cgi->delete_all();
  $fill_in->{'selfurl'} = $cgi->self_url;
  $fill_in->{'cgi'} = \$cgi;
  $fill_in->{'error'} = $cgi->param('error') if $cgi->param('error');

  my $access_info = ($session_id and $session_id ne 'login')
                      ? access_info( 'session_id' => $session_id )
                      : {};
  $fill_in->{$_} = $access_info->{$_} foreach keys %$access_info;

  # update the user's authentication
  my $timeout = $access_info->{'timeout'} || '3600';
  my $cookie = CGI::Cookie->new('-name'     => 'session',
                                '-value'    => $session_id,
                                '-expires'  => '+'.$timeout.'s',
                                #'-secure'   => 1, # would be a good idea...
                               );
  if ( $name eq 'logout' ) {
    $cookie->expires(0);
  }

  if ( $fill_in->{'format'} ) {
    # then override content-type, and return $fill_in->{'content'} instead
    # of filling in a template
    if ( $fill_in->{'format'} eq 'csv') {
      print $cgi->header('-expires' => 'now',
        '-Content-Type' => 'text/csv',
        '-Content-Disposition' => "attachment;filename=output.csv",
      );
    } elsif ( $fill_in->{'format'} eq 'xls' ) {
      print $cgi->header('-expires' => 'now',
        '-Content-Type' => 'application/vnd.ms-excel',
        '-Content-Disposition' => "attachment;filename=output.xls",
        '-Content-Length' => length($fill_in->{'content'}),
      );
    } elsif ( $fill_in->{'format'} eq 'png' ) {
      print $cgi->header('-expires' => 'now',
        '-Content-Type' => 'image/png',
      );
    }
    print $fill_in->{'content'};
  } else { # the usual case
    my $source = "$template_dir/$name.html";
    my $template = new Text::Template(
      TYPE       => 'FILE',
      SOURCE     => $source,
      DELIMITERS => [ '<%=', '%>' ],
      UNTAINT    => 1,
    )
      or die $Text::Template::ERROR;

    my $data = $template->fill_in( 
      PACKAGE => 'FS::SelfService::_selfservicecgi',
      HASH    => $fill_in,
    ) || "Error processing template $source"; # at least print _something_
    print $cgi->header( '-cookie' => $cookie,
                        '-expires' => 'now' );
    print $data;
  }
}

#*FS::SelfService::_selfservicecgi::include = \&Text::Template::fill_in_file;

package FS::SelfService::_selfservicecgi;

use HTML::Entities;
use FS::SelfService qw(
    regionselector popselector domainselector location_form didselector
);

#false laziness w/agent.cgi
use vars qw(@INCLUDE_ARGS);
sub include {
  my $name = shift;

  @INCLUDE_ARGS = @_;

  my $template = new Text::Template( TYPE   => 'FILE',
                                     SOURCE => "$main::template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                   
                                   )
    or die $Text::Template::ERROR;

  $template->fill_in( PACKAGE => 'FS::SelfService::_selfservicecgi',
                      #HASH    => $fill_in
                    );

}


