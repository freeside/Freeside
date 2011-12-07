package FS::cust_main::Billing_Realtime;

use strict;
use vars qw( $conf $DEBUG $me );
use vars qw( $realtime_bop_decline_quiet ); #ugh
use Data::Dumper;
use Business::CreditCard 0.28;
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( send_email );
use FS::payby;
use FS::cust_pay;
use FS::cust_pay_pending;
use FS::cust_refund;
use FS::banned_pay;

$realtime_bop_decline_quiet = 0;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Billing_Realtime]';

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
};

=head1 NAME

FS::cust_main::Billing_Realtime - Realtime billing mixin for cust_main

=head1 SYNOPSIS

=head1 DESCRIPTION

These methods are available on FS::cust_main objects.

=head1 METHODS

=over 4

=item realtime_collect [ OPTION => VALUE ... ]

Attempt to collect the customer's current balance with a realtime credit 
card, electronic check, or phone bill transaction (see realtime_bop() below).

Returns the result of realtime_bop(): nothing, an error message, or a 
hashref of state information for a third-party transaction.

Available options are: I<method>, I<amount>, I<description>, I<invnum>, I<quiet>, I<paynum_ref>, I<payunique>, I<session_id>, I<pkgnum>

I<method> is one of: I<CC>, I<ECHECK> and I<LEC>.  If none is specified
then it is deduced from the customer record.

If no I<amount> is specified, then the customer balance is used.

The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
if set, will override the value from the customer record.

I<description> is a free-text field passed to the gateway.  It defaults to
the value defined by the business-onlinepayment-description configuration
option, or "Internet services" if that is unset.

If an I<invnum> is specified, this payment (if successful) is applied to the
specified invoice.

I<apply> will automatically apply a resulting payment.

I<quiet> can be set true to suppress email decline notices.

I<paynum_ref> can be set to a scalar reference.  It will be filled in with the
resulting paynum, if any.

I<payunique> is a unique identifier for this payment.

I<session_id> is a session identifier associated with this payment.

I<depend_jobnum> allows payment capture to unlock export jobs

=cut

sub realtime_collect {
  my( $self, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  if ( $DEBUG ) {
    warn "$me realtime_collect:\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  $options{amount} = $self->balance unless exists( $options{amount} );
  $options{method} = FS::payby->payby2bop($self->payby)
    unless exists( $options{method} );

  return $self->realtime_bop({%options});

}

=item realtime_bop { [ ARG => VALUE ... ] }

Runs a realtime credit card, ACH (electronic check) or phone bill transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Required arguments in the hashref are I<method>, and I<amount>

Available methods are: I<CC>, I<ECHECK> and I<LEC>

Available optional arguments are: I<description>, I<invnum>, I<apply>, I<quiet>, I<paynum_ref>, I<payunique>, I<session_id>

The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
if set, will override the value from the customer record.

I<description> is a free-text field passed to the gateway.  It defaults to
the value defined by the business-onlinepayment-description configuration
option, or "Internet services" if that is unset.

If an I<invnum> is specified, this payment (if successful) is applied to the
specified invoice.  If the customer has exactly one open invoice, that 
invoice number will be assumed.  If you don't specify an I<invnum> you might 
want to call the B<apply_payments> method or set the I<apply> option.

I<apply> can be set to true to apply a resulting payment.

I<quiet> can be set true to surpress email decline notices.

I<paynum_ref> can be set to a scalar reference.  It will be filled in with the
resulting paynum, if any.

I<payunique> is a unique identifier for this payment.

I<session_id> is a session identifier associated with this payment.

I<depend_jobnum> allows payment capture to unlock export jobs

I<discount_term> attempts to take a discount by prepaying for discount_term.
The payment will fail if I<amount> is incorrect for this discount term.

A direct (Business::OnlinePayment) transaction will return nothing on success,
or an error message on failure.

A third-party transaction will return a hashref containing:

- popup_url: the URL to which a browser should be redirected to complete 
  the transaction.
- collectitems: an arrayref of name-value pairs to be posted to popup_url.
- reference: a reference ID for the transaction, to show the customer.

(moved from cust_bill) (probably should get realtime_{card,ach,lec} here too)

=cut

# some helper routines
sub _bop_recurring_billing {
  my( $self, %opt ) = @_;

  my $method = scalar($conf->config('credit_card-recurring_billing_flag'));

  if ( defined($method) && $method eq 'transaction_is_recur' ) {

    return 1 if $opt{'trans_is_recur'};

  } else {

    my %hash = ( 'custnum' => $self->custnum,
                 'payby'   => 'CARD',
               );

    return 1 
      if qsearch('cust_pay', { %hash, 'payinfo' => $opt{'payinfo'} } )
      || qsearch('cust_pay', { %hash, 'paymask' => $self->mask_payinfo('CARD',
                                                               $opt{'payinfo'} )
                             } );

  }

  return 0;

}

sub _payment_gateway {
  my ($self, $options) = @_;

  if ( $options->{'selfservice'} ) {
    my $gatewaynum = FS::Conf->new->config('selfservice-payment_gateway');
    if ( $gatewaynum ) {
      return $options->{payment_gateway} ||= 
          qsearchs('payment_gateway', { gatewaynum => $gatewaynum });
    }
  }

  if ( $options->{'fake_gatewaynum'} ) {
	$options->{payment_gateway} =
	    qsearchs('payment_gateway',
		      { 'gatewaynum' => $options->{'fake_gatewaynum'}, }
		    );
  }

  $options->{payment_gateway} = $self->agent->payment_gateway( %$options )
    unless exists($options->{payment_gateway});

  $options->{payment_gateway};
}

sub _bop_auth {
  my ($self, $options) = @_;

  (
    'login'    => $options->{payment_gateway}->gateway_username,
    'password' => $options->{payment_gateway}->gateway_password,
  );
}

sub _bop_options {
  my ($self, $options) = @_;

  $options->{payment_gateway}->gatewaynum
    ? $options->{payment_gateway}->options
    : @{ $options->{payment_gateway}->get('options') };

}

sub _bop_defaults {
  my ($self, $options) = @_;

  unless ( $options->{'description'} ) {
    if ( $conf->exists('business-onlinepayment-description') ) {
      my $dtempl = $conf->config('business-onlinepayment-description');

      my $agent = $self->agent->agent;
      #$pkgs... not here
      $options->{'description'} = eval qq("$dtempl");
    } else {
      $options->{'description'} = 'Internet services';
    }
  }

  $options->{payinfo} = $self->payinfo unless exists( $options->{payinfo} );

  # Default invoice number if the customer has exactly one open invoice.
  if( ! $options->{'invnum'} ) {
    $options->{'invnum'} = '';
    my @open = $self->open_cust_bill;
    $options->{'invnum'} = $open[0]->invnum if scalar(@open) == 1;
  }

  $options->{payname} = $self->payname unless exists( $options->{payname} );
}

sub _bop_content {
  my ($self, $options) = @_;
  my %content = ();

  my $payip = exists($options->{'payip'}) ? $options->{'payip'} : $self->payip;
  $content{customer_ip} = $payip if length($payip);

  $content{invoice_number} = $options->{'invnum'}
    if exists($options->{'invnum'}) && length($options->{'invnum'});

  $content{email_customer} = 
    (    $conf->exists('business-onlinepayment-email_customer')
      || $conf->exists('business-onlinepayment-email-override') );
      
  my ($payname, $payfirst, $paylast);
  if ( $options->{payname} && $options->{method} ne 'ECHECK' ) {
    ($payname = $options->{payname}) =~
      /^\s*([\w \,\.\-\']*)?\s+([\w\,\.\-\']+)\s*$/
      or return "Illegal payname $payname";
    ($payfirst, $paylast) = ($1, $2);
  } else {
    $payfirst = $self->getfield('first');
    $paylast = $self->getfield('last');
    $payname = "$payfirst $paylast";
  }

  $content{last_name} = $paylast;
  $content{first_name} = $payfirst;

  $content{name} = $payname;

  $content{address} = exists($options->{'address1'})
                        ? $options->{'address1'}
                        : $self->address1;
  my $address2 = exists($options->{'address2'})
                   ? $options->{'address2'}
                   : $self->address2;
  $content{address} .= ", ". $address2 if length($address2);

  $content{city} = exists($options->{city})
                     ? $options->{city}
                     : $self->city;
  $content{state} = exists($options->{state})
                      ? $options->{state}
                      : $self->state;
  $content{zip} = exists($options->{zip})
                    ? $options->{'zip'}
                    : $self->zip;
  $content{country} = exists($options->{country})
                        ? $options->{country}
                        : $self->country;

  $content{referer} = 'http://cleanwhisker.420.am/'; #XXX fix referer :/
  $content{phone} = $self->daytime || $self->night;

  my $currency =    $conf->exists('business-onlinepayment-currency')
                 && $conf->config('business-onlinepayment-currency');
  $content{currency} = $currency if $currency;

  \%content;
}

my %bop_method2payby = (
  'CC'     => 'CARD',
  'ECHECK' => 'CHEK',
  'LEC'    => 'LECB',
);

sub realtime_bop {
  my $self = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;
 
  my %options = ();
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    my ( $method, $amount ) = ( shift, shift );
    %options = @_;
    $options{method} = $method;
    $options{amount} = $amount;
  }


  ### 
  # optional credit card surcharge
  ###

  my $cc_surcharge = 0;
  my $cc_surcharge_pct = 0;
  $cc_surcharge_pct = $conf->config('credit-card-surcharge-percentage') 
    if $conf->config('credit-card-surcharge-percentage');
  
  # always add cc surcharge if called from event 
  if($options{'cc_surcharge_from_event'} && $cc_surcharge_pct > 0) {
      $cc_surcharge = $options{'amount'} * $cc_surcharge_pct / 100;
      $options{'amount'} += $cc_surcharge;
      $options{'amount'} = sprintf("%.2f", $options{'amount'}); # round (again)?
  }
  elsif($cc_surcharge_pct > 0) { # we're called not from event (i.e. from a 
                                 # payment screen), so consider the given 
				 # amount as post-surcharge
    $cc_surcharge = $options{'amount'} - ($options{'amount'} / ( 1 + $cc_surcharge_pct/100 ));
  }
  
  $cc_surcharge = sprintf("%.2f",$cc_surcharge) if $cc_surcharge > 0;
  $options{'cc_surcharge'} = $cc_surcharge;


  if ( $DEBUG ) {
    warn "$me realtime_bop (new): $options{method} $options{amount}\n";
    warn " cc_surcharge = $cc_surcharge\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  return $self->fake_bop(\%options) if $options{'fake'};

  $self->_bop_defaults(\%options);

  ###
  # set trans_is_recur based on invnum if there is one
  ###

  my $trans_is_recur = 0;
  if ( $options{'invnum'} ) {

    my $cust_bill = qsearchs('cust_bill', { 'invnum' => $options{'invnum'} } );
    die "invnum ". $options{'invnum'}. " not found" unless $cust_bill;

    my @part_pkg =
      map  { $_->part_pkg }
      grep { $_ }
      map  { $_->cust_pkg }
      $cust_bill->cust_bill_pkg;

    $trans_is_recur = 1
      if grep { $_->freq ne '0' } @part_pkg;

  }

  ###
  # select a gateway
  ###

  my $payment_gateway =  $self->_payment_gateway( \%options );
  my $namespace = $payment_gateway->gateway_namespace;

  eval "use $namespace";  
  die $@ if $@;

  ###
  # check for banned credit card/ACH
  ###

  my $ban = FS::banned_pay->ban_search(
    'payby'   => $bop_method2payby{$options{method}},
    'payinfo' => $options{payinfo},
  );
  return "Banned credit card" if $ban && $ban->bantype ne 'warn';

  ###
  # check for term discount validity
  ###

  my $discount_term = $options{discount_term};
  if ( $discount_term ) {
    my $bill = ($self->cust_bill)[-1]
      or return "Can't apply a term discount to an unbilled customer";
    my $plan = FS::discount_plan->new(
      cust_bill => $bill,
      months    => $discount_term
    ) or return "No discount available for term '$discount_term'";
    
    if ( $plan->discounted_total != $options{amount} ) {
      return "Incorrect term prepayment amount (term $discount_term, amount $options{amount}, requires ".$plan->discounted_total.")";
    }
  }

  ###
  # massage data
  ###

  my $bop_content = $self->_bop_content(\%options);
  return $bop_content unless ref($bop_content);

  my @invoicing_list = $self->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my $paydate = '';
  my %content = ();
  if ( $namespace eq 'Business::OnlinePayment' && $options{method} eq 'CC' ) {

    $content{card_number} = $options{payinfo};
    $paydate = exists($options{'paydate'})
                    ? $options{'paydate'}
                    : $self->paydate;
    $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
    $content{expiration} = "$2/$1";

    my $paycvv = exists($options{'paycvv'})
                   ? $options{'paycvv'}
                   : $self->paycvv;
    $content{cvv2} = $paycvv
      if length($paycvv);

    my $paystart_month = exists($options{'paystart_month'})
                           ? $options{'paystart_month'}
                           : $self->paystart_month;

    my $paystart_year  = exists($options{'paystart_year'})
                           ? $options{'paystart_year'}
                           : $self->paystart_year;

    $content{card_start} = "$paystart_month/$paystart_year"
      if $paystart_month && $paystart_year;

    my $payissue       = exists($options{'payissue'})
                           ? $options{'payissue'}
                           : $self->payissue;
    $content{issue_number} = $payissue if $payissue;

    if ( $self->_bop_recurring_billing( 'payinfo'        => $options{'payinfo'},
                                        'trans_is_recur' => $trans_is_recur,
                                      )
       )
    {
      $content{recurring_billing} = 'YES';
      $content{acct_code} = 'rebill'
        if $conf->exists('credit_card-recurring_billing_acct_code');
    }

  } elsif ( $namespace eq 'Business::OnlinePayment' && $options{method} eq 'ECHECK' ){
    ( $content{account_number}, $content{routing_code} ) =
      split('@', $options{payinfo});
    $content{bank_name} = $options{payname};
    $content{bank_state} = exists($options{'paystate'})
                             ? $options{'paystate'}
                             : $self->getfield('paystate');
    $content{account_type}= (exists($options{'paytype'}) && $options{'paytype'})
                               ? uc($options{'paytype'})
                               : uc($self->getfield('paytype')) || 'PERSONAL CHECKING';
    $content{account_name} = $self->getfield('first'). ' '.
                             $self->getfield('last');

    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{state_id}       = exists($options{'stateid'})
                                 ? $options{'stateid'}
                                 : $self->getfield('stateid');
    $content{state_id_state} = exists($options{'stateid_state'})
                                 ? $options{'stateid_state'}
                                 : $self->getfield('stateid_state');
    $content{customer_ssn} = exists($options{'ss'})
                               ? $options{'ss'}
                               : $self->ss;
  } elsif ( $namespace eq 'Business::OnlinePayment' && $options{method} eq 'LEC' ) {
    $content{phone} = $options{payinfo};
  } elsif ( $namespace eq 'Business::OnlineThirdPartyPayment' ) {
    #move along
  } else {
    #die an evil death
  }

  ###
  # run transaction(s)
  ###

  my $balance = exists( $options{'balance'} )
                  ? $options{'balance'}
                  : $self->balance;

  $self->select_for_update; #mutex ... just until we get our pending record in

  #the checks here are intended to catch concurrent payments
  #double-form-submission prevention is taken care of in cust_pay_pending::check

  #check the balance
  return "The customer's balance has changed; $options{method} transaction aborted."
    if $self->balance < $balance;

  #also check and make sure there aren't *other* pending payments for this cust

  my @pending = qsearch('cust_pay_pending', {
    'custnum' => $self->custnum,
    'status'  => { op=>'!=', value=>'done' } 
  });

  #for third-party payments only, remove pending payments if they're in the 
  #'thirdparty' (waiting for customer action) state.
  if ( $namespace eq 'Business::OnlineThirdPartyPayment' ) {
    foreach ( grep { $_->status eq 'thirdparty' } @pending ) {
      my $error = $_->delete;
      warn "error deleting unfinished third-party payment ".
          $_->paypendingnum . ": $error\n"
        if $error;
    }
    @pending = grep { $_->status ne 'thirdparty' } @pending;
  }

  return "A payment is already being processed for this customer (".
         join(', ', map 'paypendingnum '. $_->paypendingnum, @pending ).
         "); $options{method} transaction aborted."
    if scalar(@pending);

  #okay, good to go, if we're a duplicate, cust_pay_pending will kick us out

  my $cust_pay_pending = new FS::cust_pay_pending {
    'custnum'           => $self->custnum,
    'paid'              => $options{amount},
    '_date'             => '',
    'payby'             => $bop_method2payby{$options{method}},
    'payinfo'           => $options{payinfo},
    'paydate'           => $paydate,
    'recurring_billing' => $content{recurring_billing},
    'pkgnum'            => $options{'pkgnum'},
    'status'            => 'new',
    'gatewaynum'        => $payment_gateway->gatewaynum || '',
    'session_id'        => $options{session_id} || '',
    'jobnum'            => $options{depend_jobnum} || '',
  };
  $cust_pay_pending->payunique( $options{payunique} )
    if defined($options{payunique}) && length($options{payunique});
  my $cpp_new_err = $cust_pay_pending->insert; #mutex lost when this is inserted
  return $cpp_new_err if $cpp_new_err;

  my( $action1, $action2 ) =
    split( /\s*\,\s*/, $payment_gateway->gateway_action );

  my $transaction = new $namespace( $payment_gateway->gateway_module,
                                    $self->_bop_options(\%options),
                                  );

  $transaction->content(
    'type'           => $options{method},
    $self->_bop_auth(\%options),          
    'action'         => $action1,
    'description'    => $options{'description'},
    'amount'         => $options{amount},
    #'invoice_number' => $options{'invnum'},
    'customer_id'    => $self->custnum,
    %$bop_content,
    'reference'      => $cust_pay_pending->paypendingnum, #for now
    'callback_url'   => $payment_gateway->gateway_callback_url,
    'email'          => $email,
    %content, #after
  );

  $cust_pay_pending->status('pending');
  my $cpp_pending_err = $cust_pay_pending->replace;
  return $cpp_pending_err if $cpp_pending_err;

  #config?
  my $BOP_TESTING = 0;
  my $BOP_TESTING_SUCCESS = 1;

  unless ( $BOP_TESTING ) {
    $transaction->test_transaction(1)
      if $conf->exists('business-onlinepayment-test_transaction');
    $transaction->submit();
  } else {
    if ( $BOP_TESTING_SUCCESS ) {
      $transaction->is_success(1);
      $transaction->authorization('fake auth');
    } else {
      $transaction->is_success(0);
      $transaction->error_message('fake failure');
    }
  }

  if ( $transaction->is_success() && $namespace eq 'Business::OnlineThirdPartyPayment' ) {

    $cust_pay_pending->status('thirdparty');
    my $cpp_err = $cust_pay_pending->replace;
    return { error => $cpp_err } if $cpp_err;
    return { reference => $cust_pay_pending->paypendingnum,
             map { $_ => $transaction->$_ } qw ( popup_url collectitems ) };

  } elsif ( $transaction->is_success() && $action2 ) {

    $cust_pay_pending->status('authorized');
    my $cpp_authorized_err = $cust_pay_pending->replace;
    return $cpp_authorized_err if $cpp_authorized_err;

    my $auth = $transaction->authorization;
    my $ordernum = $transaction->can('order_number')
                   ? $transaction->order_number
                   : '';

    my $capture =
      new Business::OnlinePayment( $payment_gateway->gateway_module,
                                   $self->_bop_options(\%options),
                                 );

    my %capture = (
      %content,
      type           => $options{method},
      action         => $action2,
      $self->_bop_auth(\%options),          
      order_number   => $ordernum,
      amount         => $options{amount},
      authorization  => $auth,
      description    => $options{'description'},
    );

    foreach my $field (qw( authorization_source_code returned_ACI
                           transaction_identifier validation_code           
                           transaction_sequence_num local_transaction_date    
                           local_transaction_time AVS_result_code          )) {
      $capture{$field} = $transaction->$field() if $transaction->can($field);
    }

    $capture->content( %capture );

    $capture->test_transaction(1)
      if $conf->exists('business-onlinepayment-test_transaction');
    $capture->submit();

    unless ( $capture->is_success ) {
      my $e = "Authorization successful but capture failed, custnum #".
              $self->custnum. ': '.  $capture->result_code.
              ": ". $capture->error_message;
      warn $e;
      return $e;
    }

  }

  ###
  # remove paycvv after initial transaction
  ###

  #false laziness w/misc/process/payment.cgi - check both to make sure working
  # correctly
  if ( length($self->paycvv)
       && ! grep { $_ eq cardtype($options{payinfo}) } $conf->config('cvv-save')
  ) {
    my $error = $self->remove_cvv;
    if ( $error ) {
      warn "WARNING: error removing cvv: $error\n";
    }
  }

  ###
  # Tokenize
  ###


  if ( $transaction->can('card_token') && $transaction->card_token ) {

    $self->card_token($transaction->card_token);

    if ( $options{'payinfo'} eq $self->payinfo ) {
      $self->payinfo($transaction->card_token);
      my $error = $self->replace;
      if ( $error ) {
        warn "WARNING: error storing token: $error, but proceeding anyway\n";
      }
    }

  }

  ###
  # result handling
  ###

  $self->_realtime_bop_result( $cust_pay_pending, $transaction, %options );

}

=item fake_bop

=cut

sub fake_bop {
  my $self = shift;

  my %options = ();
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    my ( $method, $amount ) = ( shift, shift );
    %options = @_;
    $options{method} = $method;
    $options{amount} = $amount;
  }
  
  if ( $options{'fake_failure'} ) {
     return "Error: No error; test failure requested with fake_failure";
  }

  #my $paybatch = '';
  #if ( $payment_gateway->gatewaynum ) { # agent override
  #  $paybatch = $payment_gateway->gatewaynum. '-';
  #}
  #
  #$paybatch .= "$processor:". $transaction->authorization;
  #
  #$paybatch .= ':'. $transaction->order_number
  #  if $transaction->can('order_number')
  #  && length($transaction->order_number);

  my $paybatch = 'FakeProcessor:54:32';

  my $cust_pay = new FS::cust_pay ( {
     'custnum'  => $self->custnum,
     'invnum'   => $options{'invnum'},
     'paid'     => $options{amount},
     '_date'    => '',
     'payby'    => $bop_method2payby{$options{method}},
     #'payinfo'  => $payinfo,
     'payinfo'  => '4111111111111111',
     'paybatch' => $paybatch,
     #'paydate'  => $paydate,
     'paydate'  => '2012-05-01',
  } );
  $cust_pay->payunique( $options{payunique} ) if length($options{payunique});

  if ( $DEBUG ) {
      warn "fake_bop\n cust_pay: ". Dumper($cust_pay) . "\n options: ";
      warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  my $error = $cust_pay->insert($options{'manual'} ? ( 'manual' => 1 ) : () );

  if ( $error ) {
    $cust_pay->invnum(''); #try again with no specific invnum
    my $error2 = $cust_pay->insert( $options{'manual'} ?
                                    ( 'manual' => 1 ) : ()
                                  );
    if ( $error2 ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card/ACH debited but database not updated - '.
              "error inserting (fake!) payment: $error2".
              " (previously tried insert with invnum #$options{'invnum'}" .
              ": $error )";
      warn $e;
      return $e;
    }
  }

  if ( $options{'paynum_ref'} ) {
    ${ $options{'paynum_ref'} } = $cust_pay->paynum;
  }

  return ''; #no error

}


# item _realtime_bop_result CUST_PAY_PENDING, BOP_OBJECT [ OPTION => VALUE ... ]
# 
# Wraps up processing of a realtime credit card, ACH (electronic check) or
# phone bill transaction.

sub _realtime_bop_result {
  my( $self, $cust_pay_pending, $transaction, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  if ( $DEBUG ) {
    warn "$me _realtime_bop_result: pending transaction ".
      $cust_pay_pending->paypendingnum. "\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  my $payment_gateway = $options{payment_gateway}
    or return "no payment gateway in arguments to _realtime_bop_result";

  $cust_pay_pending->status($transaction->is_success() ? 'captured' : 'declined');
  my $cpp_captured_err = $cust_pay_pending->replace;
  return $cpp_captured_err if $cpp_captured_err;

  if ( $transaction->is_success() ) {

    my $paybatch = '';
    if ( $payment_gateway->gatewaynum ) { # agent override
      $paybatch = $payment_gateway->gatewaynum. '-';
    }

    $paybatch .= $payment_gateway->gateway_module. ":".
      $transaction->authorization;

    $paybatch .= ':'. $transaction->order_number
      if $transaction->can('order_number')
      && length($transaction->order_number);

    my $cust_pay = new FS::cust_pay ( {
       'custnum'  => $self->custnum,
       'invnum'   => $options{'invnum'},
       'paid'     => $cust_pay_pending->paid,
       '_date'    => '',
       'payby'    => $cust_pay_pending->payby,
       'payinfo'  => $options{'payinfo'},
       'paybatch' => $paybatch,
       'paydate'  => $cust_pay_pending->paydate,
       'pkgnum'   => $cust_pay_pending->pkgnum,
       'discount_term' => $options{'discount_term'},
    } );
    #doesn't hurt to know, even though the dup check is in cust_pay_pending now
    $cust_pay->payunique( $options{payunique} )
      if defined($options{payunique}) && length($options{payunique});

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    #start a transaction, insert the cust_pay and set cust_pay_pending.status to done in a single transction

    my $error = $cust_pay->insert($options{'manual'} ? ( 'manual' => 1 ) : () );

    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      $cust_pay->invnum(''); #try again with no specific invnum
      $cust_pay->paynum('');
      my $error2 = $cust_pay->insert( $options{'manual'} ?
                                      ( 'manual' => 1 ) : ()
                                    );
      if ( $error2 ) {
        # gah.  but at least we have a record of the state we had to abort in
        # from cust_pay_pending now.
        $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
        my $e = "WARNING: $options{method} captured but payment not recorded -".
                " error inserting payment (". $payment_gateway->gateway_module.
                "): $error2".
                " (previously tried insert with invnum #$options{'invnum'}" .
                ": $error ) - pending payment saved as paypendingnum ".
                $cust_pay_pending->paypendingnum. "\n";
        warn $e;
        return $e;
      }
    }

    my $jobnum = $cust_pay_pending->jobnum;
    if ( $jobnum ) {
       my $placeholder = qsearchs( 'queue', { 'jobnum' => $jobnum } );
      
       unless ( $placeholder ) {
         $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
         my $e = "WARNING: $options{method} captured but job $jobnum not ".
             "found for paypendingnum ". $cust_pay_pending->paypendingnum. "\n";
         warn $e;
         return $e;
       }

       $error = $placeholder->delete;

       if ( $error ) {
         $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
         my $e = "WARNING: $options{method} captured but could not delete ".
              "job $jobnum for paypendingnum ".
              $cust_pay_pending->paypendingnum. ": $error\n";
         warn $e;
         return $e;
       }

    }
    
    if ( $options{'paynum_ref'} ) {
      ${ $options{'paynum_ref'} } = $cust_pay->paynum;
    }

    $cust_pay_pending->status('done');
    $cust_pay_pending->statustext('captured');
    $cust_pay_pending->paynum($cust_pay->paynum);
    my $cpp_done_err = $cust_pay_pending->replace;

    if ( $cpp_done_err ) {

      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      my $e = "WARNING: $options{method} captured but payment not recorded - ".
              "error updating status for paypendingnum ".
              $cust_pay_pending->paypendingnum. ": $cpp_done_err \n";
      warn $e;
      return $e;

    } else {

      $dbh->commit or die $dbh->errstr if $oldAutoCommit;

      if ( $options{'apply'} ) {
        my $apply_error = $self->apply_payments_and_credits;
        if ( $apply_error ) {
          warn "WARNING: error applying payment: $apply_error\n";
          #but we still should return no error cause the payment otherwise went
          #through...
        }
      }

      # have a CC surcharge portion --> one-time charge
      if ( $options{'cc_surcharge'} > 0 ) { 
	    # XXX: this whole block needs to be in a transaction?

	  my $invnum;
	  $invnum = $options{'invnum'} if $options{'invnum'};
	  unless ( $invnum ) { # probably from a payment screen
	     # do we have any open invoices? pick earliest
	     # uses the fact that cust_main->cust_bill sorts by date ascending
	     my @open = $self->open_cust_bill;
	     $invnum = $open[0]->invnum if scalar(@open);
	  }
	    
	  unless ( $invnum ) {  # still nothing? pick last closed invoice
	     # again uses fact that cust_main->cust_bill sorts by date ascending
	     my @closed = $self->cust_bill;
	     $invnum = $closed[$#closed]->invnum if scalar(@closed);
	  }

	  unless ( $invnum ) {
	    # XXX: unlikely case - pre-paying before any invoices generated
	    # what it should do is create a new invoice and pick it
		warn 'CC SURCHARGE AND NO INVOICES PICKED TO APPLY IT!';
		return '';
	  }

	  my $cust_pkg;
	  my $charge_error = $self->charge({
				    'amount' 	=> $options{'cc_surcharge'},
				    'pkg' 	=> 'Credit Card Surcharge',
				    'setuptax'  => 'Y',
				    'cust_pkg_ref' => \$cust_pkg,
				});
	  if($charge_error) {
		warn 'Unable to add CC surcharge cust_pkg';
		return '';
	  }

	  $cust_pkg->setup(time);
	  my $cp_error = $cust_pkg->replace;
	  if($cp_error) {
	      warn 'Unable to set setup time on cust_pkg for cc surcharge';
	    # but keep going...
	  }
				    
	  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $invnum });
	  unless ( $cust_bill ) {
	      warn "race condition + invoice deletion just happened";
	      return '';
	  }

	  my $grand_error = 
	    $cust_bill->add_cc_surcharge($cust_pkg->pkgnum,$options{'cc_surcharge'});

	  warn "cannot add CC surcharge to invoice #$invnum: $grand_error"
	    if $grand_error;
      }

      return ''; #no error

    }

  } else {

    my $perror = $payment_gateway->gateway_module. " error: ".
      $transaction->error_message;

    my $jobnum = $cust_pay_pending->jobnum;
    if ( $jobnum ) {
       my $placeholder = qsearchs( 'queue', { 'jobnum' => $jobnum } );
      
       if ( $placeholder ) {
         my $error = $placeholder->depended_delete;
         $error ||= $placeholder->delete;
         warn "error removing provisioning jobs after declined paypendingnum ".
           $cust_pay_pending->paypendingnum. ": $error\n";
       } else {
         my $e = "error finding job $jobnum for declined paypendingnum ".
              $cust_pay_pending->paypendingnum. "\n";
         warn $e;
       }

    }
    
    unless ( $transaction->error_message ) {

      my $t_response;
      if ( $transaction->can('response_page') ) {
        $t_response = {
                        'page'    => ( $transaction->can('response_page')
                                         ? $transaction->response_page
                                         : ''
                                     ),
                        'code'    => ( $transaction->can('response_code')
                                         ? $transaction->response_code
                                         : ''
                                     ),
                        'headers' => ( $transaction->can('response_headers')
                                         ? $transaction->response_headers
                                         : ''
                                     ),
                      };
      } else {
        $t_response .=
          "No additional debugging information available for ".
            $payment_gateway->gateway_module;
      }

      $perror .= "No error_message returned from ".
                   $payment_gateway->gateway_module. " -- ".
                 ( ref($t_response) ? Dumper($t_response) : $t_response );

    }

    if ( !$options{'quiet'} && !$realtime_bop_decline_quiet
         && $conf->exists('emaildecline', $self->agentnum)
         && grep { $_ ne 'POST' } $self->invoicing_list
         && ! grep { $transaction->error_message =~ /$_/ }
                   $conf->config('emaildecline-exclude', $self->agentnum)
    ) {

      # Send a decline alert to the customer.
      my $msgnum = $conf->config('decline_msgnum', $self->agentnum);
      my $error = '';
      if ( $msgnum ) {
        # include the raw error message in the transaction state
        $cust_pay_pending->setfield('error', $transaction->error_message);
        my $msg_template = qsearchs('msg_template', { msgnum => $msgnum });
        $error = $msg_template->send( 'cust_main' => $self,
                                      'object'    => $cust_pay_pending );
      }
      else { #!$msgnum

        my @templ = $conf->config('declinetemplate');
        my $template = new Text::Template (
          TYPE   => 'ARRAY',
          SOURCE => [ map "$_\n", @templ ],
        ) or return "($perror) can't create template: $Text::Template::ERROR";
        $template->compile()
          or return "($perror) can't compile template: $Text::Template::ERROR";

        my $templ_hash = {
          'company_name'    =>
            scalar( $conf->config('company_name', $self->agentnum ) ),
          'company_address' =>
            join("\n", $conf->config('company_address', $self->agentnum ) ),
          'error'           => $transaction->error_message,
        };

        my $error = send_email(
          'from'    => $conf->config('invoice_from', $self->agentnum ),
          'to'      => [ grep { $_ ne 'POST' } $self->invoicing_list ],
          'subject' => 'Your payment could not be processed',
          'body'    => [ $template->fill_in(HASH => $templ_hash) ],
        );
      }

      $perror .= " (also received error sending decline notification: $error)"
        if $error;

    }

    $cust_pay_pending->status('done');
    $cust_pay_pending->statustext("declined: $perror");
    my $cpp_done_err = $cust_pay_pending->replace;
    if ( $cpp_done_err ) {
      my $e = "WARNING: $options{method} declined but pending payment not ".
              "resolved - error updating status for paypendingnum ".
              $cust_pay_pending->paypendingnum. ": $cpp_done_err \n";
      warn $e;
      $perror = "$e ($perror)";
    }

    return $perror;
  }

}

=item realtime_botpp_capture CUST_PAY_PENDING [ OPTION => VALUE ... ]

Verifies successful third party processing of a realtime credit card,
ACH (electronic check) or phone bill transaction via a
Business::OnlineThirdPartyPayment realtime gateway.  See
L<http://420.am/business-onlinethirdpartypayment> for supported gateways.

Available options are: I<description>, I<invnum>, I<quiet>, I<paynum_ref>, I<payunique>

The additional options I<payname>, I<city>, I<state>,
I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
if set, will override the value from the customer record.

I<description> is a free-text field passed to the gateway.  It defaults to
"Internet services".

If an I<invnum> is specified, this payment (if successful) is applied to the
specified invoice.  If you don't specify an I<invnum> you might want to
call the B<apply_payments> method.

I<quiet> can be set true to surpress email decline notices.

I<paynum_ref> can be set to a scalar reference.  It will be filled in with the
resulting paynum, if any.

I<payunique> is a unique identifier for this payment.

Returns a hashref containing elements bill_error (which will be undefined
upon success) and session_id of any associated session.

=cut

sub realtime_botpp_capture {
  my( $self, $cust_pay_pending, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  if ( $DEBUG ) {
    warn "$me realtime_botpp_capture: pending transaction $cust_pay_pending\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  eval "use Business::OnlineThirdPartyPayment";  
  die $@ if $@;

  ###
  # select the gateway
  ###

  my $method = FS::payby->payby2bop($cust_pay_pending->payby);

  my $payment_gateway;
  my $gatewaynum = $cust_pay_pending->getfield('gatewaynum');
  $payment_gateway = $gatewaynum ? qsearchs( 'payment_gateway',
                { gatewaynum => $gatewaynum }
              )
    : $self->agent->payment_gateway( 'method' => $method,
                                     # 'invnum'  => $cust_pay_pending->invnum,
                                     # 'payinfo' => $cust_pay_pending->payinfo,
                                   );

  $options{payment_gateway} = $payment_gateway; # for the helper subs

  ###
  # massage data
  ###

  my @invoicing_list = $self->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my %content = ();

  $content{email_customer} = 
    (    $conf->exists('business-onlinepayment-email_customer')
      || $conf->exists('business-onlinepayment-email-override') );
      
  ###
  # run transaction(s)
  ###

  my $transaction =
    new Business::OnlineThirdPartyPayment( $payment_gateway->gateway_module,
                                           $self->_bop_options(\%options),
                                         );

  $transaction->reference({ %options }); 

  $transaction->content(
    'type'           => $method,
    $self->_bop_auth(\%options),
    'action'         => 'Post Authorization',
    'description'    => $options{'description'},
    'amount'         => $cust_pay_pending->paid,
    #'invoice_number' => $options{'invnum'},
    'customer_id'    => $self->custnum,
    'referer'        => 'http://cleanwhisker.420.am/',
    'reference'      => $cust_pay_pending->paypendingnum,
    'email'          => $email,
    'phone'          => $self->daytime || $self->night,
    %content, #after
    # plus whatever is required for bogus capture avoidance
  );

  $transaction->submit();

  my $error =
    $self->_realtime_bop_result( $cust_pay_pending, $transaction, %options );

  if ( $options{'apply'} ) {
    my $apply_error = $self->apply_payments_and_credits;
    if ( $apply_error ) {
      warn "WARNING: error applying payment: $apply_error\n";
    }
  }

  return {
    bill_error => $error,
    session_id => $cust_pay_pending->session_id,
  }

}

=item default_payment_gateway

DEPRECATED -- use agent->payment_gateway

=cut

sub default_payment_gateway {
  my( $self, $method ) = @_;

  die "Real-time processing not enabled\n"
    unless $conf->exists('business-onlinepayment');

  #warn "default_payment_gateway deprecated -- use agent->payment_gateway\n";

  #load up config
  my $bop_config = 'business-onlinepayment';
  $bop_config .= '-ach'
    if $method =~ /^(ECHECK|CHEK)$/ && $conf->exists($bop_config. '-ach');
  my ( $processor, $login, $password, $action, @bop_options ) =
    $conf->config($bop_config);
  $action ||= 'normal authorization';
  pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
  die "No real-time processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n"
    unless $processor;

  ( $processor, $login, $password, $action, @bop_options )
}

=item realtime_refund_bop METHOD [ OPTION => VALUE ... ]

Refunds a realtime credit card, ACH (electronic check) or phone bill transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Available methods are: I<CC>, I<ECHECK> and I<LEC>

Available options are: I<amount>, I<reason>, I<paynum>, I<paydate>

Most gateways require a reference to an original payment transaction to refund,
so you probably need to specify a I<paynum>.

I<amount> defaults to the original amount of the payment if not specified.

I<reason> specifies a reason for the refund.

I<paydate> specifies the expiration date for a credit card overriding the
value from the customer record or the payment record. Specified as yyyy-mm-dd

Implementation note: If I<amount> is unspecified or equal to the amount of the
orignal payment, first an attempt is made to "void" the transaction via
the gateway (to cancel a not-yet settled transaction) and then if that fails,
the normal attempt is made to "refund" ("credit") the transaction via the
gateway is attempted. No attempt to "void" the transaction is made if the 
gateway has introspection data and doesn't support void.

#The additional options I<payname>, I<address1>, I<address2>, I<city>, I<state>,
#I<zip>, I<payinfo> and I<paydate> are also available.  Any of these options,
#if set, will override the value from the customer record.

#If an I<invnum> is specified, this payment (if successful) is applied to the
#specified invoice.  If you don't specify an I<invnum> you might want to
#call the B<apply_payments> method.

=cut

#some false laziness w/realtime_bop, not enough to make it worth merging
#but some useful small subs should be pulled out
sub realtime_refund_bop {
  my $self = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my %options = ();
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    my $method = shift;
    %options = @_;
    $options{method} = $method;
  }

  if ( $DEBUG ) {
    warn "$me realtime_refund_bop (new): $options{method} refund\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  ###
  # look up the original payment and optionally a gateway for that payment
  ###

  my $cust_pay = '';
  my $amount = $options{'amount'};

  my( $processor, $login, $password, @bop_options, $namespace ) ;
  my( $auth, $order_number ) = ( '', '', '' );

  if ( $options{'paynum'} ) {

    warn "  paynum: $options{paynum}\n" if $DEBUG > 1;
    $cust_pay = qsearchs('cust_pay', { paynum=>$options{'paynum'} } )
      or return "Unknown paynum $options{'paynum'}";
    $amount ||= $cust_pay->paid;

    $cust_pay->paybatch =~ /^((\d+)\-)?(\w+):\s*([\w\-\/ ]*)(:([\w\-]+))?$/
      or return "Can't parse paybatch for paynum $options{'paynum'}: ".
                $cust_pay->paybatch;
    my $gatewaynum = '';
    ( $gatewaynum, $processor, $auth, $order_number ) = ( $2, $3, $4, $6 );

    if ( $gatewaynum ) { #gateway for the payment to be refunded

      my $payment_gateway =
        qsearchs('payment_gateway', { 'gatewaynum' => $gatewaynum } );
      die "payment gateway $gatewaynum not found"
        unless $payment_gateway;

      $processor   = $payment_gateway->gateway_module;
      $login       = $payment_gateway->gateway_username;
      $password    = $payment_gateway->gateway_password;
      $namespace   = $payment_gateway->gateway_namespace;
      @bop_options = $payment_gateway->options;

    } else { #try the default gateway

      my $conf_processor;
      my $payment_gateway =
        $self->agent->payment_gateway('method' => $options{method});

      ( $conf_processor, $login, $password, $namespace ) =
        map { my $method = "gateway_$_"; $payment_gateway->$method }
          qw( module username password namespace );

      @bop_options = $payment_gateway->gatewaynum
                       ? $payment_gateway->options
                       : @{ $payment_gateway->get('options') };

      return "processor of payment $options{'paynum'} $processor does not".
             " match default processor $conf_processor"
        unless $processor eq $conf_processor;

    }


  } else { # didn't specify a paynum, so look for agent gateway overrides
           # like a normal transaction 
 
    my $payment_gateway =
      $self->agent->payment_gateway( 'method'  => $options{method},
                                     #'payinfo' => $payinfo,
                                   );
    my( $processor, $login, $password, $namespace ) =
      map { my $method = "gateway_$_"; $payment_gateway->$method }
        qw( module username password namespace );

    my @bop_options = $payment_gateway->gatewaynum
                        ? $payment_gateway->options
                        : @{ $payment_gateway->get('options') };

  }
  return "neither amount nor paynum specified" unless $amount;

  eval "use $namespace";  
  die $@ if $@;

  my %content = (
    'type'           => $options{method},
    'login'          => $login,
    'password'       => $password,
    'order_number'   => $order_number,
    'amount'         => $amount,
    'referer'        => 'http://cleanwhisker.420.am/', #XXX fix referer :/
  );
  $content{authorization} = $auth
    if length($auth); #echeck/ACH transactions have an order # but no auth
                      #(at least with authorize.net)

  my $disable_void_after;
  if ($conf->exists('disable_void_after')
      && $conf->config('disable_void_after') =~ /^(\d+)$/) {
    $disable_void_after = $1;
  }

  #first try void if applicable
  my $void = new Business::OnlinePayment( $processor, @bop_options );

  my $tryvoid = 1;
  if ($void->can('info')) {
      my $paytype = '';
      $paytype = 'ECHECK' if $cust_pay && $cust_pay->payby eq 'CHEK';
      $paytype = 'CC' if $cust_pay && $cust_pay->payby eq 'CARD';
      my %supported_actions = $void->info('supported_actions');
      $tryvoid = 0 
        if ( %supported_actions && $paytype 
                && defined($supported_actions{$paytype}) 
                && !grep{ $_ eq 'Void' } @{$supported_actions{$paytype}} );
  }

  if ( $cust_pay && $cust_pay->paid == $amount
    && (
      ( not defined($disable_void_after) )
      || ( time < ($cust_pay->_date + $disable_void_after ) )
    )
    && $tryvoid
  ) {
    warn "  attempting void\n" if $DEBUG > 1;
    if ( $void->can('info') ) {
      if ( $cust_pay->payby eq 'CARD'
           && $void->info('CC_void_requires_card') )
      {
        $content{'card_number'} = $cust_pay->payinfo;
      } elsif ( $cust_pay->payby eq 'CHEK'
                && $void->info('ECHECK_void_requires_account') )
      {
        ( $content{'account_number'}, $content{'routing_code'} ) =
          split('@', $cust_pay->payinfo);
        $content{'name'} = $self->get('first'). ' '. $self->get('last');
      }
    }
    $void->content( 'action' => 'void', %content );
    $void->test_transaction(1)
      if $conf->exists('business-onlinepayment-test_transaction');
    $void->submit();
    if ( $void->is_success ) {
      my $error = $cust_pay->void($options{'reason'});
      if ( $error ) {
        # gah, even with transactions.
        my $e = 'WARNING: Card/ACH voided but database not updated - '.
                "error voiding payment: $error";
        warn $e;
        return $e;
      }
      warn "  void successful\n" if $DEBUG > 1;
      return '';
    }
  }

  warn "  void unsuccessful, trying refund\n"
    if $DEBUG > 1;

  #massage data
  my $address = $self->address1;
  $address .= ", ". $self->address2 if $self->address2;

  my($payname, $payfirst, $paylast);
  if ( $self->payname && $options{method} ne 'ECHECK' ) {
    $payname = $self->payname;
    $payname =~ /^\s*([\w \,\.\-\']*)?\s+([\w\,\.\-\']+)\s*$/
      or return "Illegal payname $payname";
    ($payfirst, $paylast) = ($1, $2);
  } else {
    $payfirst = $self->getfield('first');
    $paylast = $self->getfield('last');
    $payname =  "$payfirst $paylast";
  }

  my @invoicing_list = $self->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $self->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my $payip = exists($options{'payip'})
                ? $options{'payip'}
                : $self->payip;
  $content{customer_ip} = $payip
    if length($payip);

  my $payinfo = '';
  if ( $options{method} eq 'CC' ) {

    if ( $cust_pay ) {
      $content{card_number} = $payinfo = $cust_pay->payinfo;
      (exists($options{'paydate'}) ? $options{'paydate'} : $cust_pay->paydate)
        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/ &&
        ($content{expiration} = "$2/$1");  # where available
    } else {
      $content{card_number} = $payinfo = $self->payinfo;
      (exists($options{'paydate'}) ? $options{'paydate'} : $self->paydate)
        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
      $content{expiration} = "$2/$1";
    }

  } elsif ( $options{method} eq 'ECHECK' ) {

    if ( $cust_pay ) {
      $payinfo = $cust_pay->payinfo;
    } else {
      $payinfo = $self->payinfo;
    } 
    ( $content{account_number}, $content{routing_code} )= split('@', $payinfo );
    $content{bank_name} = $self->payname;
    $content{account_type} = 'CHECKING';
    $content{account_name} = $payname;
    $content{customer_org} = $self->company ? 'B' : 'I';
    $content{customer_ssn} = $self->ss;
  } elsif ( $options{method} eq 'LEC' ) {
    $content{phone} = $payinfo = $self->payinfo;
  }

  #then try refund
  my $refund = new Business::OnlinePayment( $processor, @bop_options );
  my %sub_content = $refund->content(
    'action'         => 'credit',
    'customer_id'    => $self->custnum,
    'last_name'      => $paylast,
    'first_name'     => $payfirst,
    'name'           => $payname,
    'address'        => $address,
    'city'           => $self->city,
    'state'          => $self->state,
    'zip'            => $self->zip,
    'country'        => $self->country,
    'email'          => $email,
    'phone'          => $self->daytime || $self->night,
    %content, #after
  );
  warn join('', map { "  $_ => $sub_content{$_}\n" } keys %sub_content )
    if $DEBUG > 1;
  $refund->test_transaction(1)
    if $conf->exists('business-onlinepayment-test_transaction');
  $refund->submit();

  return "$processor error: ". $refund->error_message
    unless $refund->is_success();

  my $paybatch = "$processor:". $refund->authorization;
  $paybatch .= ':'. $refund->order_number
    if $refund->can('order_number') && $refund->order_number;

  while ( $cust_pay && $cust_pay->unapplied < $amount ) {
    my @cust_bill_pay = $cust_pay->cust_bill_pay;
    last unless @cust_bill_pay;
    my $cust_bill_pay = pop @cust_bill_pay;
    my $error = $cust_bill_pay->delete;
    last if $error;
  }

  my $cust_refund = new FS::cust_refund ( {
    'custnum'  => $self->custnum,
    'paynum'   => $options{'paynum'},
    'refund'   => $amount,
    '_date'    => '',
    'payby'    => $bop_method2payby{$options{method}},
    'payinfo'  => $payinfo,
    'paybatch' => $paybatch,
    'reason'   => $options{'reason'} || 'card or ACH refund',
  } );
  my $error = $cust_refund->insert;
  if ( $error ) {
    $cust_refund->paynum(''); #try again with no specific paynum
    my $error2 = $cust_refund->insert;
    if ( $error2 ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card/ACH refunded but database not updated - '.
              "error inserting refund ($processor): $error2".
              " (previously tried insert with paynum #$options{'paynum'}" .
              ": $error )";
      warn $e;
      return $e;
    }
  }

  ''; #no error

}

=back

=head1 BUGS

Not autoloaded.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_main::Billing>

=cut

1;
