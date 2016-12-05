package FS::cust_main::Billing_Realtime;

use strict;
use vars qw( $conf $DEBUG $me );
use vars qw( $realtime_bop_decline_quiet ); #ugh
use Carp;
use Data::Dumper;
use Business::CreditCard 0.35;
use FS::UID qw( dbh myconnect );
use FS::Record qw( qsearch qsearchs );
use FS::payby;
use FS::cust_pay;
use FS::cust_pay_pending;
use FS::cust_bill_pay;
use FS::cust_refund;
use FS::banned_pay;
use FS::payment_gateway;

$realtime_bop_decline_quiet = 0;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Billing_Realtime]';

our $BOP_TESTING = 0;
our $BOP_TESTING_SUCCESS = 1;

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

=item realtime_cust_payby

=cut

sub realtime_cust_payby {
  my( $self, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  $options{amount} = $self->balance unless exists( $options{amount} );

  my @cust_payby = $self->cust_payby('CARD','CHEK');
                                                   
  my $error;
  foreach my $cust_payby (@cust_payby) {
    $error = $cust_payby->realtime_bop( %options, );
    last unless $error;
  }

  #XXX what about the earlier errors?

  $error;

}

=item realtime_collect [ OPTION => VALUE ... ]

Attempt to collect the customer's current balance with a realtime credit 
card or electronic check transaction (see realtime_bop() below).

Returns the result of realtime_bop(): nothing, an error message, or a 
hashref of state information for a third-party transaction.

Available options are: I<method>, I<amount>, I<description>, I<invnum>, I<quiet>, I<paynum_ref>, I<payunique>, I<session_id>, I<pkgnum>

I<method> is one of: I<CC> or I<ECHECK>.  If none is specified
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

# Currently only used by ClientAPI
sub realtime_collect {
  my( $self, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  if ( $DEBUG ) {
    warn "$me realtime_collect:\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  $options{amount} = $self->balance unless exists( $options{amount} );
  return '' unless $options{amount} > 0;

  return $self->realtime_bop({%options});

}

=item realtime_bop { [ ARG => VALUE ... ] }

Runs a realtime credit card or ACH (electronic check) transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Required arguments in the hashref are I<amount> and either
I<cust_payby> or I<method>, I<payinfo> and (as applicable for method)
I<payname>, I<address1>, I<address2>, I<city>, I<state>, I<zip> and I<paydate>.

Available methods are: I<CC>, I<ECHECK>, or I<PAYPAL>

Available optional arguments are: I<description>, I<invnum>, I<apply>, I<quiet>, I<paynum_ref>, I<payunique>, I<session_id>

I<description> is a free-text field passed to the gateway.  It defaults to
the value defined by the business-onlinepayment-description configuration
option, or "Internet services" if that is unset.

If an I<invnum> is specified, this payment (if successful) is applied to the
specified invoice.  If the customer has exactly one open invoice, that 
invoice number will be assumed.  If you don't specify an I<invnum> you might 
want to call the B<apply_payments> method or set the I<apply> option.

I<no_invnum> can be set to true to prevent that default invnum from being set.

I<apply> can be set to true to run B<apply_payments_and_credits> on success.

I<no_auto_apply> can be set to true to set that flag on the resulting payment
(prevents payment from being applied by B<apply_payments> or B<apply_payments_and_credits>,
but will still be applied if I<invnum> exists...use with I<no_invnum> for intended effect.)

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
#
# _bop_recurring_billing: Checks whether this payment should have the 
# recurring_billing flag used by some B:OP interfaces (IPPay, PlugnPay,
# vSecure, etc.). This works in two different modes:
# - actual_oncard (default): treat the payment as recurring if the customer
#   has made a payment using this card before.
# - transaction_is_recur: treat the payment as recurring if the invoice
#   being paid has any recurring package charges.

sub _bop_recurring_billing {
  my( $self, %opt ) = @_;

  my $method = scalar($conf->config('credit_card-recurring_billing_flag'));

  if ( defined($method) && $method eq 'transaction_is_recur' ) {

    return 1 if $opt{'trans_is_recur'};

  } else {

    # return 1 if the payinfo has been used for another payment
    return $self->payinfo_used($opt{'payinfo'}); # in payinfo_Mixin

  }

  return 0;

}

#can run safely as class method if opt payment_gateway already exists
sub _payment_gateway {
  my ($self, $options) = @_;

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

# not a method!!!
sub _bop_auth {
  my ($options) = @_;

  (
    'login'    => $options->{payment_gateway}->gateway_username,
    'password' => $options->{payment_gateway}->gateway_password,
  );
}

### not a method!
sub _bop_options {
  my ($options) = @_;

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

  # Default invoice number if the customer has exactly one open invoice.
  unless ( $options->{'invnum'} || $options->{'no_invnum'} ) {
    $options->{'invnum'} = '';
    my @open = $self->open_cust_bill;
    $options->{'invnum'} = $open[0]->invnum if scalar(@open) == 1;
  }

}

# not a method!
sub _bop_cust_payby_options {
  my ($options) = @_;
  my $cust_payby = $options->{'cust_payby'};
  if ($cust_payby) {

    $options->{'method'} = FS::payby->payby2bop( $cust_payby->payby );

    if ($cust_payby->payby =~ /^(CARD|DCRD)$/) {
      # false laziness with cust_payby->check
      #   which might not have been run yet
      my( $m, $y );
      if ( $cust_payby->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
        ( $m, $y ) = ( $1, length($2) == 4 ? $2 : "20$2" );
      } elsif ( $cust_payby->paydate =~ /^19(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
        ( $m, $y ) = ( $2, "19$1" );
      } elsif ( $cust_payby->paydate =~ /^(20)?(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
        ( $m, $y ) = ( $3, "20$2" );
      } else {
        return "Illegal expiration date: ". $cust_payby->paydate;
      }
      $m = sprintf('%02d',$m);
      $options->{paydate} = "$y-$m-01";
    } else {
      $options->{paydate} = '';
    }

    $options->{$_} = $cust_payby->$_() 
      for qw( payinfo paycvv paymask paystart_month paystart_year 
              payissue payname paystate paytype payip );

    if ( $cust_payby->locationnum ) {
      my $cust_location = $cust_payby->cust_location;
      $options->{$_} = $cust_location->$_() for qw( address1 address2 city state zip );
    }
  }
}

# can be called as class method,
# but can't load default name/phone fields as class method
sub _bop_content {
  my ($self, $options) = @_;
  my %content = ();

  my $payip = $options->{'payip'};
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
  } elsif (ref($self)) { # can't set payname if called as class method
    $payfirst = $self->getfield('first');
    $paylast = $self->getfield('last');
    $payname = "$payfirst $paylast";
  }

  $content{last_name} = $paylast if $paylast;
  $content{first_name} = $payfirst if $payfirst;

  $content{name} = $payname if $payname;

  $content{address} = $options->{'address1'};
  my $address2 = $options->{'address2'};
  $content{address} .= ", ". $address2 if length($address2);

  $content{city} = $options->{'city'};
  $content{state} = $options->{'state'};
  $content{zip} = $options->{'zip'};
  $content{country} = $options->{'country'};

  # can't set phone if called as class method
  $content{phone} = $self->daytime || $self->night
    if ref($self);

  my $currency =    $conf->exists('business-onlinepayment-currency')
                 && $conf->config('business-onlinepayment-currency');
  $content{currency} = $currency if $currency;

  \%content;
}

# updates payinfo and cust_payby options with token from transaction
# can be called as a class method
sub _tokenize_card {
  my ($self,$transaction,$options) = @_;
  if ( $transaction->can('card_token') 
       and $transaction->card_token 
       and !$self->tokenized($options->{'payinfo'})
  ) {
    $options->{'payinfo'} = $transaction->card_token;
    $options->{'cust_payby'}->payinfo($transaction->card_token) if $options->{'cust_payby'};
    return $transaction->card_token;
  }
  return '';
}

my %bop_method2payby = (
  'CC'     => 'CARD',
  'ECHECK' => 'CHEK',
  'PAYPAL' => 'PPAL',
);

sub realtime_bop {
  my $self = shift;

  confess "Can't call realtime_bop within another transaction ".
          '($FS::UID::AutoCommit is false)'
    unless $FS::UID::AutoCommit;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $log = FS::Log->new('FS::cust_main::Billing_Realtime::realtime_bop');
 
  my %options = ();
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    my ( $method, $amount ) = ( shift, shift );
    %options = @_;
    $options{method} = $method;
    $options{amount} = $amount;
  }

  # set fields from passed cust_payby
  _bop_cust_payby_options(\%options);

  # possibly run a separate transaction to tokenize card number,
  #   so that we never store tokenized card info in cust_pay_pending
  if (($options{method} eq 'CC') && !$self->tokenized($options{'payinfo'})) {
    my $token_error = $self->realtime_tokenize(\%options);
    return $token_error if $token_error;
    # in theory, all cust_payby will be tokenized during original save,
    # so we shouldn't get here with opt cust_payby...but just in case...
    if ($options{'cust_payby'} && $self->tokenized($options{'payinfo'})) {
      $token_error = $options{'cust_payby'}->replace;
      return $token_error if $token_error;
    }
  }

  ### 
  # optional credit card surcharge
  ###

  my $cc_surcharge = 0;
  my $cc_surcharge_pct = 0;
  $cc_surcharge_pct = $conf->config('credit-card-surcharge-percentage', $self->agentnum) 
    if $conf->config('credit-card-surcharge-percentage', $self->agentnum)
    && $options{method} eq 'CC';

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
  }
  if ( $DEBUG > 2 ) {
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  return $self->fake_bop(\%options) if $options{'fake'};

  $self->_bop_defaults(\%options);

  return "Missing payinfo"
    unless $options{'payinfo'};

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

  if ( $namespace eq 'Business::OnlinePayment' ) {

    if ( $options{method} eq 'CC' ) {

      $content{card_number} = $options{payinfo};
      $paydate = $options{'paydate'};
      $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
      $content{expiration} = "$2/$1";

      $content{cvv2} = $options{'paycvv'}
        if length($options{'paycvv'});

      my $paystart_month = $options{'paystart_month'};
      my $paystart_year  = $options{'paystart_year'};
      $content{card_start} = "$paystart_month/$paystart_year"
        if $paystart_month && $paystart_year;

      my $payissue       = $options{'payissue'};
      $content{issue_number} = $payissue if $payissue;

      if ( $self->_bop_recurring_billing(
             'payinfo'        => $options{'payinfo'},
             'trans_is_recur' => $trans_is_recur,
           )
         )
      {
        $content{recurring_billing} = 'YES';
        $content{acct_code} = 'rebill'
          if $conf->exists('credit_card-recurring_billing_acct_code');
      }

    } elsif ( $options{method} eq 'ECHECK' ){

      ( $content{account_number}, $content{routing_code} ) =
        split('@', $options{payinfo});
      $content{bank_name} = $options{payname};
      $content{bank_state} = $options{'paystate'};
      $content{account_type}= uc($options{'paytype'}) || 'PERSONAL CHECKING';

      $content{company} = $self->company if $self->company;

      if ( $content{account_type} =~ /BUSINESS/i && $self->company ) {
        $content{account_name} = $self->company;
      } else {
        $content{account_name} = $self->getfield('first'). ' '.
                                 $self->getfield('last');
      }

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

    } else {
      die "unknown method ". $options{method};
    }

  } elsif ( $namespace eq 'Business::OnlineThirdPartyPayment' ) {
    #move along
  } else {
    die "unknown namespace $namespace";
  }

  ###
  # run transaction(s)
  ###

  my $balance = exists( $options{'balance'} )
                  ? $options{'balance'}
                  : $self->balance;

  warn "claiming mutex on customer ". $self->custnum. "\n" if $DEBUG > 1;
  $self->select_for_update; #mutex ... just until we get our pending record in
  warn "obtained mutex on customer ". $self->custnum. "\n" if $DEBUG > 1;

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
    'paymask'           => $options{paymask},
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

  warn "inserting cust_pay_pending record for customer ". $self->custnum. "\n"
    if $DEBUG > 1;
  my $cpp_new_err = $cust_pay_pending->insert; #mutex lost when this is inserted
  return $cpp_new_err if $cpp_new_err;

  warn "inserted cust_pay_pending record for customer ". $self->custnum. "\n"
    if $DEBUG > 1;
  warn Dumper($cust_pay_pending) if $DEBUG > 2;

  my( $action1, $action2 ) =
    split( /\s*\,\s*/, $payment_gateway->gateway_action );

  my $transaction = new $namespace( $payment_gateway->gateway_module,
                                    _bop_options(\%options),
                                  );

  $transaction->content(
    'type'           => $options{method},
    _bop_auth(\%options),          
    'action'         => $action1,
    'description'    => $options{'description'},
    'amount'         => $options{amount},
    #'invoice_number' => $options{'invnum'},
    'customer_id'    => $self->custnum,
    %$bop_content,
    'reference'      => $cust_pay_pending->paypendingnum, #for now
    'callback_url'   => $payment_gateway->gateway_callback_url,
    'cancel_url'     => $payment_gateway->gateway_cancel_url,
    'email'          => $email,
    %content, #after
  );

  $cust_pay_pending->status('pending');
  my $cpp_pending_err = $cust_pay_pending->replace;
  return $cpp_pending_err if $cpp_pending_err;

  warn Dumper($transaction) if $DEBUG > 2;

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
                                   _bop_options(\%options),
                                 );

    my %capture = (
      %content,
      type           => $options{method},
      action         => $action2,
      _bop_auth(\%options),          
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

  # compare to FS::cust_main::save_cust_payby - check both to make sure working correctly
  if ( length($options{'paycvv'})
       && ! grep { $_ eq cardtype($options{payinfo}) } $conf->config('cvv-save')
  ) {
    my $error = $self->remove_cvv_from_cust_payby($options{payinfo});
    if ( $error ) {
      $log->critical('Error removing cvv for cust '.$self->custnum.': '.$error);
      #not returning error, should at least attempt to handle results of an otherwise valid transaction
      warn "WARNING: error removing cvv: $error\n";
    }
  }

  ###
  # Tokenize
  ###

  # This block will only run if the B::OP module supports card_token but not the Tokenize transaction;
  #   if that never happens, we should get rid of it (as it has the potential to store real card numbers on error)
  if (my $card_token = $self->_tokenize_card($transaction,\%options)) {
    # cpp will be replaced in _realtime_bop_result
    $cust_pay_pending->payinfo($card_token);
    if ($options{'cust_payby'} and my $error = $options{'cust_payby'}->replace) {
      $log->critical('Error storing token for cust '.$self->custnum.', cust_payby '.$options{'cust_payby'}->custpaybynum.': '.$error);
      #not returning error, should at least attempt to handle results of an otherwise valid transaction
      #this leaves real card number in cust_payby, but can't do much else if cust_payby won't replace
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

  my $cust_pay = new FS::cust_pay ( {
     'custnum'  => $self->custnum,
     'invnum'   => $options{'invnum'},
     'paid'     => $options{amount},
     '_date'    => '',
     'payby'    => $bop_method2payby{$options{method}},
     'payinfo'  => '4111111111111111',
     'paydate'  => '2012-05-01',
     'processor'      => 'FakeProcessor',
     'auth'           => '54',
     'order_number'   => '32',
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
# Wraps up processing of a realtime credit card or ACH (electronic check)
# transaction.

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
  my $cpp_captured_err = $cust_pay_pending->replace; #also saves post-transaction tokenization, if that happens
  return $cpp_captured_err if $cpp_captured_err;

  if ( $transaction->is_success() ) {

    my $order_number = $transaction->order_number
      if $transaction->can('order_number');

    my $cust_pay = new FS::cust_pay ( {
       'custnum'  => $self->custnum,
       'invnum'   => $options{'invnum'},
       'paid'     => $cust_pay_pending->paid,
       '_date'    => '',
       'payby'    => $cust_pay_pending->payby,
       'payinfo'  => $options{'payinfo'},
       'paymask'  => $options{'paymask'} || $cust_pay_pending->paymask,
       'paydate'  => $cust_pay_pending->paydate,
       'pkgnum'   => $cust_pay_pending->pkgnum,
       'discount_term'  => $options{'discount_term'},
       'gatewaynum'     => ($payment_gateway->gatewaynum || ''),
       'processor'      => $payment_gateway->gateway_module,
       'auth'           => $transaction->authorization,
       'order_number'   => $order_number || '',
       'no_auto_apply'  => $options{'no_auto_apply'} ? 'Y' : '',
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

       $cust_pay_pending->set('jobnum','');

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

    my $perror = $transaction->error_message;
    #$payment_gateway->gateway_module. " error: ".
    # removed for conciseness

    my $jobnum = $cust_pay_pending->jobnum;
    if ( $jobnum ) {
       my $placeholder = qsearchs( 'queue', { 'jobnum' => $jobnum } );
      
       if ( $placeholder ) {
         my $error = $placeholder->depended_delete;
         $error ||= $placeholder->delete;
         $cust_pay_pending->set('jobnum','');
         warn "error removing provisioning jobs after declined paypendingnum ".
           $cust_pay_pending->paypendingnum. ": $error\n" if $error;
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


      $perror .= " (also received error sending decline notification: $error)"
        if $error;

    }

    $cust_pay_pending->status('done');
    $cust_pay_pending->statustext($perror);
    #'declined:': no, that's failure_status
    if ( $transaction->can('failure_status') ) {
      $cust_pay_pending->failure_status( $transaction->failure_status );
    }
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

Verifies successful third party processing of a realtime credit card or
ACH (electronic check) transaction via a
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
                                           _bop_options(\%options),
                                         );

  $transaction->reference({ %options }); 

  $transaction->content(
    'type'           => $method,
    _bop_auth(\%options),
    'action'         => 'Post Authorization',
    'description'    => $options{'description'},
    'amount'         => $cust_pay_pending->paid,
    #'invoice_number' => $options{'invnum'},
    'customer_id'    => $self->custnum,
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

Refunds a realtime credit card or ACH (electronic check) transaction
via a Business::OnlinePayment realtime gateway.  See
L<http://420.am/business-onlinepayment> for supported gateways.

Available methods are: I<CC> or I<ECHECK>

Available options are: I<amount>, I<reasonnum>, I<paynum>, I<paydate>

Most gateways require a reference to an original payment transaction to refund,
so you probably need to specify a I<paynum>.

I<amount> defaults to the original amount of the payment if not specified.

I<reasonnum> specified an existing refund reason for the refund

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

  return "No reason specified" unless $options{'reasonnum'} =~ /^\d+$/;

  my %content = ();

  ###
  # look up the original payment and optionally a gateway for that payment
  ###

  my $cust_pay = '';
  my $amount = $options{'amount'};

  my( $processor, $login, $password, @bop_options, $namespace ) ;
  my( $auth, $order_number ) = ( '', '', '' );
  my $gatewaynum = '';

  if ( $options{'paynum'} ) {

    warn "  paynum: $options{paynum}\n" if $DEBUG > 1;
    $cust_pay = qsearchs('cust_pay', { paynum=>$options{'paynum'} } )
      or return "Unknown paynum $options{'paynum'}";
    $amount ||= $cust_pay->paid;

    my @cust_bill_pay = qsearch('cust_bill_pay', { paynum=>$cust_pay->paynum });
    $content{'invoice_number'} = $cust_bill_pay[0]->invnum if @cust_bill_pay;

    if ( $cust_pay->get('processor') ) {
      ($gatewaynum, $processor, $auth, $order_number) =
      (
        $cust_pay->gatewaynum,
        $cust_pay->processor,
        $cust_pay->auth,
        $cust_pay->order_number,
      );
    } else {
      # this payment wasn't upgraded, which probably means this won't work,
      # but try it anyway
      $cust_pay->paybatch =~ /^((\d+)\-)?(\w+):\s*([\w\-\/ ]*)(:([\w\-]+))?$/
        or return "Can't parse paybatch for paynum $options{'paynum'}: ".
                  $cust_pay->paybatch;
      ( $gatewaynum, $processor, $auth, $order_number ) = ( $2, $3, $4, $6 );
    }

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
      my %bop_options = @bop_options;

      return "processor of payment $options{'paynum'} $processor does not".
             " match default processor $conf_processor"
        unless ($processor eq $conf_processor)
            || (($conf_processor eq 'CardFortress') && ($processor eq $bop_options{'gateway'}));

    }


  } else { # didn't specify a paynum, so look for agent gateway overrides
           # like a normal transaction 
 
    my $payment_gateway =
      $self->agent->payment_gateway( 'method'  => $options{method} );
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

  %content = (
    %content,
    'type'           => $options{method},
    'login'          => $login,
    'password'       => $password,
    'order_number'   => $order_number,
    'amount'         => $amount,
  );
  $content{authorization} = $auth
    if length($auth); #echeck/ACH transactions have an order # but no auth
                      #(at least with authorize.net)

  my $currency =    $conf->exists('business-onlinepayment-currency')
                 && $conf->config('business-onlinepayment-currency');
  $content{currency} = $currency if $currency;

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
      # specified as a refund reason, but now we want a payment void reason
      # extract just the reason text, let cust_pay::void handle new_or_existing
      my $reason = qsearchs('reason',{ 'reasonnum' => $options{'reasonnum'} });
      my $error;
      $error = 'Reason could not be loaded' unless $reason;      
      $error = $cust_pay->void($reason->reason) unless $error;
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
  my $paymask = ''; # for refund record
  if ( $options{method} eq 'CC' ) {

    if ( $cust_pay ) {
      $content{card_number} = $payinfo = $cust_pay->payinfo;
      $paymask = $cust_pay->paymask;
      (exists($options{'paydate'}) ? $options{'paydate'} : $cust_pay->paydate)
        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/ &&
        ($content{expiration} = "$2/$1");  # where available
    } else {
      # this really needs a better cleanup
      die "Refund without paynum not supported";
#      $content{card_number} = $payinfo = $self->payinfo;
#      (exists($options{'paydate'}) ? $options{'paydate'} : $self->paydate)
#        =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
#      $content{expiration} = "$2/$1";
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

  $order_number = $refund->order_number if $refund->can('order_number');

  # change this to just use $cust_pay->delete_cust_bill_pay?
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
    'source_paynum' => $options{'paynum'},
    'refund'   => $amount,
    '_date'    => '',
    'payby'    => $bop_method2payby{$options{method}},
    'payinfo'  => $payinfo,
    'paymask'  => $paymask,
    'reasonnum'     => $options{'reasonnum'},
    'gatewaynum'    => $gatewaynum, # may be null
    'processor'     => $processor,
    'auth'          => $refund->authorization,
    'order_number'  => $order_number,
  } );
  my $error = $cust_refund->insert;
  if ( $error ) {
    $cust_refund->paynum(''); #try again with no specific paynum
    $cust_refund->source_paynum('');
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

=item realtime_verify_bop [ OPTION => VALUE ... ]

Runs an authorization-only transaction for $1 against this credit card (if
successful, immediatly reverses the authorization).

Returns the empty string if the authorization was sucessful, or an error
message otherwise.

Option I<cust_payby> should be passed, even if it's not yet been inserted.
Object will be tokenized if possible, but that change will not be
updated in database (must be inserted/replaced afterwards.)

Currently only succeeds for Business::OnlinePayment CC transactions.

=cut

#some false laziness w/realtime_bop and realtime_refund_bop, not enough to make
#it worth merging but some useful small subs should be pulled out
sub realtime_verify_bop {
  my $self = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;
  my $log = FS::Log->new('FS::cust_main::Billing_Realtime::realtime_verify_bop');

  my %options = ();
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
  } else {
    %options = @_;
  }

  if ( $DEBUG ) {
    warn "$me realtime_verify_bop\n";
    warn "  $_ => $options{$_}\n" foreach keys %options;
  }

  # set fields from passed cust_payby
  return "No cust_payby" unless $options{'cust_payby'};
  _bop_cust_payby_options(\%options);

  # possibly run a separate transaction to tokenize card number,
  #   so that we never store tokenized card info in cust_pay_pending
  if (($options{method} eq 'CC') && !$self->tokenized($options{'payinfo'})) {
    my $token_error = $self->realtime_tokenize(\%options);
    return $token_error if $token_error;
    #important that we not replace cust_payby here,
    #because cust_payby->replace uses realtime_verify_bop!
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
    'payby'   => $bop_method2payby{'CC'},
    'payinfo' => $options{payinfo},
  );
  return "Banned credit card" if $ban && $ban->bantype ne 'warn';

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

  if ( $namespace eq 'Business::OnlinePayment' ) {

    if ( $options{method} eq 'CC' ) {

      $content{card_number} = $options{payinfo};
      $paydate = $options{'paydate'};
      $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
      $content{expiration} = "$2/$1";

      $content{cvv2} = $options{'paycvv'}
        if length($options{'paycvv'});

      my $paystart_month = $options{'paystart_month'};
      my $paystart_year  = $options{'paystart_year'};

      $content{card_start} = "$paystart_month/$paystart_year"
        if $paystart_month && $paystart_year;

      my $payissue       = $options{'payissue'};
      $content{issue_number} = $payissue if $payissue;

    } elsif ( $options{method} eq 'ECHECK' ){
      #cannot verify, move along (though it shouldn't be called...)
      return '';
    } else {
      return "unknown method ". $options{method};
    }
  } elsif ( $namespace eq 'Business::OnlineThirdPartyPayment' ) {
    #cannot verify, move along
    return '';
  } else {
    return "unknown namespace $namespace";
  }

  ###
  # run transaction(s)
  ###

  my $error;
  my $transaction; #need this back so we can do _tokenize_card

  # don't mutex the customer here, because they might be uncommitted. and
  # this is only verification. it doesn't matter if they have other
  # unfinished verifications.

  my $cust_pay_pending = new FS::cust_pay_pending {
    'custnum_pending'   => 1,
    'paid'              => '1.00',
    '_date'             => '',
    'payby'             => $bop_method2payby{'CC'},
    'payinfo'           => $options{payinfo},
    'paymask'           => $options{paymask},
    'paydate'           => $paydate,
    'pkgnum'            => $options{'pkgnum'},
    'status'            => 'new',
    'gatewaynum'        => $payment_gateway->gatewaynum || '',
    'session_id'        => $options{session_id} || '',
  };
  $cust_pay_pending->payunique( $options{payunique} )
    if defined($options{payunique}) && length($options{payunique});

  IMMEDIATE: {
    # open a separate handle for creating/updating the cust_pay_pending
    # record
    local $FS::UID::dbh = myconnect();
    local $FS::UID::AutoCommit = 1;

    # if this is an existing customer (and we can tell now because
    # this is a fresh transaction), it's safe to assign their custnum
    # to the cust_pay_pending record, and then the verification attempt
    # will remain linked to them even if it fails.
    if ( FS::cust_main->by_key($self->custnum) ) {
      $cust_pay_pending->set('custnum', $self->custnum);
    }

    warn "inserting cust_pay_pending record for customer ". $self->custnum. "\n"
      if $DEBUG > 1;

    # if this fails, just return; everything else will still allow the
    # cust_pay_pending to have its custnum set later
    my $cpp_new_err = $cust_pay_pending->insert;
    return $cpp_new_err if $cpp_new_err;

    warn "inserted cust_pay_pending record for customer ". $self->custnum. "\n"
      if $DEBUG > 1;
    warn Dumper($cust_pay_pending) if $DEBUG > 2;

    $transaction = new $namespace( $payment_gateway->gateway_module,
                                   _bop_options(\%options),
                                    );

    $transaction->content(
      'type'           => 'CC',
      _bop_auth(\%options),          
      'action'         => 'Authorization Only',
      'description'    => $options{'description'},
      'amount'         => '1.00',
      'customer_id'    => $self->custnum,
      %$bop_content,
      'reference'      => $cust_pay_pending->paypendingnum, #for now
      'email'          => $email,
      %content, #after
    );

    $cust_pay_pending->status('pending');
    my $cpp_pending_err = $cust_pay_pending->replace;
    return $cpp_pending_err if $cpp_pending_err;

    warn Dumper($transaction) if $DEBUG > 2;

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

    if ( $transaction->is_success() ) {

      $cust_pay_pending->status('authorized');
      my $cpp_authorized_err = $cust_pay_pending->replace;
      return $cpp_authorized_err if $cpp_authorized_err;

      my $auth = $transaction->authorization;
      my $ordernum = $transaction->can('order_number')
                     ? $transaction->order_number
                     : '';

      my $reverse = new $namespace( $payment_gateway->gateway_module,
                                    _bop_options(\%options),
                                  );

      $reverse->content( 'action'        => 'Reverse Authorization',
                         _bop_auth(\%options),          

                         # B:OP
                         'amount'        => '1.00',
                         'authorization' => $transaction->authorization,
                         'order_number'  => $ordernum,

                         # vsecure
                         'result_code'   => $transaction->result_code,
                         'txn_date'      => $transaction->txn_date,

                         %content,
                       );
      $reverse->test_transaction(1)
        if $conf->exists('business-onlinepayment-test_transaction');
      $reverse->submit();

      if ( $reverse->is_success ) {

        $cust_pay_pending->status('done');
        $cust_pay_pending->statustext('reversed');
        my $cpp_reversed_err = $cust_pay_pending->replace;
        return $cpp_reversed_err if $cpp_reversed_err;

      } else {

        my $e = "Authorization successful but reversal failed, custnum #".
                $self->custnum. ': '.  $reverse->result_code.
                ": ". $reverse->error_message;
        $log->warning($e);
        warn $e;
        return $e;

      }

      ### Address Verification ###
      #
      # Single-letter codes vary by cardtype.
      #
      # Erring on the side of accepting cards if avs is not available,
      # only rejecting if avs occurred and there's been an explicit mismatch
      #
      # Charts below taken from vSecure documentation,
      #    shows codes for Amex/Dscv/MC/Visa
      #
      # ACCEPTABLE AVS RESPONSES:
      # Both Address and 5-digit postal code match Y A Y Y
      # Both address and 9-digit postal code match Y A X Y
      # United Kingdom – Address and postal code match _ _ _ F
      # International transaction – Address and postal code match _ _ _ D/M
      #
      # ACCEPTABLE, BUT ISSUE A WARNING:
      # Ineligible transaction; or message contains a content error _ _ _ E
      # System unavailable; retry R U R R
      # Information unavailable U W U U
      # Issuer does not support AVS S U S S
      # AVS is not applicable _ _ _ S
      # Incompatible formats – Not verified _ _ _ C
      # Incompatible formats – Address not verified; postal code matches _ _ _ P
      # International transaction – address not verified _ G _ G/I
      #
      # UNACCEPTABLE AVS RESPONSES:
      # Only Address matches A Y A A
      # Only 5-digit postal code matches Z Z Z Z
      # Only 9-digit postal code matches Z Z W W
      # Neither address nor postal code matches N N N N

      if (my $avscode = uc($transaction->avs_code)) {

        # map codes to accept/warn/reject
        my $avs = {
          'American Express card' => {
            'A' => 'r',
            'N' => 'r',
            'R' => 'w',
            'S' => 'w',
            'U' => 'w',
            'Y' => 'a',
            'Z' => 'r',
          },
          'Discover card' => {
            'A' => 'a',
            'G' => 'w',
            'N' => 'r',
            'U' => 'w',
            'W' => 'w',
            'Y' => 'r',
            'Z' => 'r',
          },
          'MasterCard' => {
            'A' => 'r',
            'N' => 'r',
            'R' => 'w',
            'S' => 'w',
            'U' => 'w',
            'W' => 'r',
            'X' => 'a',
            'Y' => 'a',
            'Z' => 'r',
          },
          'VISA card' => {
            'A' => 'r',
            'C' => 'w',
            'D' => 'a',
            'E' => 'w',
            'F' => 'a',
            'G' => 'w',
            'I' => 'w',
            'M' => 'a',
            'N' => 'r',
            'P' => 'w',
            'R' => 'w',
            'S' => 'w',
            'U' => 'w',
            'W' => 'r',
            'Y' => 'a',
            'Z' => 'r',
          },
        };
        my $cardtype = cardtype($content{card_number});
        if ($avs->{$cardtype}) {
          my $avsact = $avs->{$cardtype}->{$avscode};
          my $warning = '';
          if ($avsact eq 'r') {
            return "AVS code verification failed, cardtype $cardtype, code $avscode";
          } elsif ($avsact eq 'w') {
            $warning = "AVS did not occur, cardtype $cardtype, code $avscode";
          } elsif (!$avsact) {
            $warning = "AVS code unknown, cardtype $cardtype, code $avscode";
          } # else $avsact eq 'a'
          if ($warning) {
            $log->warning($warning);
            warn $warning;
          }
        } # else $cardtype avs handling not implemented
      } # else !$transaction->avs_code

    } else { # is not success

      # status is 'done' not 'declined', as in _realtime_bop_result
      $cust_pay_pending->status('done');
      $error = $transaction->error_message || 'Unknown error';
      $cust_pay_pending->statustext($error);
      # could also record failure_status here,
      #   but it's not supported by B::OP::vSecureProcessing...
      #   need a B::OP module with (reverse) auth only to test it with
      my $cpp_declined_err = $cust_pay_pending->replace;
      return $cpp_declined_err if $cpp_declined_err;

    }

  } # end of IMMEDIATE; we now have our $error and $transaction

  ###
  # Save the custnum (as part of the main transaction, so it can reference
  # the cust_main)
  ###

  if (!$cust_pay_pending->custnum) {
    $cust_pay_pending->set('custnum', $self->custnum);
    my $set_custnum_err = $cust_pay_pending->replace;
    if ($set_custnum_err) {
      $log->error($set_custnum_err);
      $error ||= $set_custnum_err;
      # but if there was a real verification error also, return that one
    }
  }

  ###
  # remove paycvv here?  need to find out if a reversed auth
  #   counts as an initial transaction for paycvv retention requirements
  ###

  ###
  # Tokenize
  ###

  # This block will only run if the B::OP module supports card_token but not the Tokenize transaction;
  #   if that never happens, we should get rid of it (as it has the potential to store real card numbers on error)
  if (my $card_token = $self->_tokenize_card($transaction,\%options)) {
    $cust_pay_pending->payinfo($card_token);
    my $cpp_token_err = $cust_pay_pending->replace;
    #this leaves real card number in cust_pay_pending, but can't do much else if cpp won't replace
    return $cpp_token_err if $cpp_token_err;
    #important that we not replace cust_payby here,
    #because cust_payby->replace uses realtime_verify_bop!
  }

  ###
  # result handling
  ###

  # $error contains the transaction error_message, if is_success was false.
 
  return $error;

}

=item realtime_tokenize [ OPTION => VALUE ... ]

If possible and necessary, runs a tokenize transaction.
In order to be possible, a credit card cust_payby record
must be passed and a Business::OnlinePayment gateway capable
of Tokenize transactions must be configured for this user.
Is only necessary if payinfo is not yet tokenized.

Returns the empty string if the authorization was sucessful
or was not possible/necessary (thus allowing this to be safely called with
non-tokenizable records/gateways, without having to perform separate tests),
or an error message otherwise.

Option I<cust_payby> may be passed, even if it's not yet been inserted.
Object will be tokenized if possible, but that change will not be
updated in database (must be inserted/replaced afterwards.)

Otherwise, options I<method>, I<payinfo> and other cust_payby fields
may be passed.  If options are passed as a hashref, I<payinfo>
will be updated as appropriate in the passed hashref.

Can be run as a class method if option I<payment_gateway> is passed,
but default customer id/name/phone can't be set in that case.  This
is really only intended for tokenizing old records on upgrade.

=cut

# careful--might be run as a class method
sub realtime_tokenize {
  my $self = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;
  my $log = FS::Log->new('FS::cust_main::Billing_Realtime::realtime_tokenize');

  my %options = ();
  my $outoptions; #for returning cust_payby/payinfo
  if (ref($_[0]) eq 'HASH') {
    %options = %{$_[0]};
    $outoptions = $_[0];
  } else {
    %options = @_;
    $outoptions = \%options;
  }

  # set fields from passed cust_payby
  _bop_cust_payby_options(\%options);
  return '' unless $options{method} eq 'CC';
  return '' if $self->tokenized($options{payinfo}); #already tokenized

  ###
  # select a gateway
  ###

  $options{'nofatal'} = 1;
  my $payment_gateway =  $self->_payment_gateway( \%options );
  return '' unless $payment_gateway;
  my $namespace = $payment_gateway->gateway_namespace;
  return '' unless $namespace eq 'Business::OnlinePayment';

  eval "use $namespace";  
  return $@ if $@;

  ###
  # check for tokenize ability
  ###

  my $transaction = new $namespace( $payment_gateway->gateway_module,
                                    _bop_options(\%options),
                                  );

  return '' unless $transaction->can('info');

  my %supported_actions = $transaction->info('supported_actions');
  return '' unless $supported_actions{'CC'} and grep(/^Tokenize$/,@{$supported_actions{'CC'}});

  ###
  # check for banned credit card/ACH
  ###

  my $ban = FS::banned_pay->ban_search(
    'payby'   => $bop_method2payby{'CC'},
    'payinfo' => $options{payinfo},
  );
  return "Banned credit card" if $ban && $ban->bantype ne 'warn';

  ###
  # massage data
  ###

  ### Currently, cardfortress only keys in on card number and exp date.
  ### We pass everything we'd pass to a normal transaction,
  ### for ease of current and future development,
  ### but note, when tokenizing old records, we may only have access to payinfo/paydate

  my $bop_content = $self->_bop_content(\%options);
  return $bop_content unless ref($bop_content);

  my $paydate = '';
  my %content = ();

  $content{card_number} = $options{payinfo};
  $paydate = $options{'paydate'};
  $paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
  $content{expiration} = "$2/$1";

  $content{cvv2} = $options{'paycvv'}
    if length($options{'paycvv'});

  my $paystart_month = $options{'paystart_month'};
  my $paystart_year  = $options{'paystart_year'};

  $content{card_start} = "$paystart_month/$paystart_year"
    if $paystart_month && $paystart_year;

  my $payissue       = $options{'payissue'};
  $content{issue_number} = $payissue if $payissue;

  $content{customer_id} = $self->custnum
    if ref($self);

  ###
  # run transaction
  ###

  my $error;

  # no cust_pay_pending---this is not a financial transaction

  $transaction->content(
    'type'           => 'CC',
    _bop_auth(\%options),          
    'action'         => 'Tokenize',
    'description'    => $options{'description'},
    %$bop_content,
    %content, #after
  );

  # no $BOP_TESTING handling for this
  $transaction->test_transaction(1)
    if $conf->exists('business-onlinepayment-test_transaction');
  $transaction->submit();

  if ( $transaction->card_token() ) { # no is_success flag

    # realtime_tokenize should not clear paycvv at this time.  it might be
    # needed for the first transaction, and a tokenize isn't actually a
    # transaction that hits the gateway.  at some point in the future, card
    # fortress should take on the "store paycvv until first transaction"
    # functionality and we should fix this in freeside, but i that's a bigger
    # project for another time.

    #important that we not replace cust_payby here, 
    #because cust_payby->replace uses realtime_tokenize!
    $self->_tokenize_card($transaction,$outoptions);

  } else {

    $error = $transaction->error_message || 'Unknown error when tokenizing card';

  }

  return $error;

}


=item tokenized PAYINFO

Convenience wrapper for L<FS::payinfo_Mixin/tokenized>

PAYINFO is required.

Can be run as class or object method, never loads from object.

=cut

sub tokenized {
  my $this = shift;
  my $payinfo = shift;
  FS::cust_pay->tokenized($payinfo);
}

=item token_check [ quiet => 1, queue => 1, daily => 1 ]

NOT A METHOD.  Acts on all customers.  Placed here because it makes
use of module-internal methods, and to keep everything that uses
Billing::OnlinePayment all in one place.

Tokenizes all tokenizable card numbers from payinfo in cust_payby and 
CARD transactions in cust_pay_pending, cust_pay, cust_pay_void and cust_refund.

If the I<queue> flag is set, newly tokenized records will be immediately
committed, regardless of AutoCommit, so as to release the mutex on the record.

If all configured gateways have the ability to tokenize, detection of an 
untokenizable record will cause a fatal error.  However, if the I<queue> flag 
is set, this will instead cause a critical error to be recorded in the log, 
and any other tokenizable records will still be committed.

If the I<daily> flag is also set, detection of existing untokenized records will 
record a critical error in the system log (because they should have never appeared 
in the first place.)  Tokenization will still be attempted.

If any configured gateways do NOT have the ability to tokenize, or if a
default gateway is not configured, then untokenized records are not considered 
a threat, and no critical errors will be generated in the log.

=cut

sub token_check {
  #acts on all customers
  my %opt = @_;
  my $debug = !$opt{'quiet'} || $DEBUG;

  warn "token_check called with opts\n".Dumper(\%opt) if $debug;

  # force some explicitness when invoking this method
  die "token_check must run with queue flag if run with daily flag"
    if $opt{'daily'} && !$opt{'queue'};

  my $conf = FS::Conf->new;

  my $log = FS::Log->new('FS::cust_main::Billing_Realtime::token_check');

  my $cache = {}; #cache for module info

  # look for a gateway that can't tokenize
  my $require_tokenized = 1;
  foreach my $gateway (
    FS::payment_gateway->all_gateways(
      'method'  => 'CC',
      'conf'    => $conf,
      'nofatal' => 1,
    )
  ) {
    if (!$gateway) {
      # no default gateway, no promise to tokenize
      # can just load other gateways as-needeed below
      $require_tokenized = 0;
      last;
    }
    my $info = _token_check_gateway_info($cache,$gateway);
    die $info unless ref($info); # means it's an error message
    unless ($info->{'can_tokenize'}) {
      # a configured gateway can't tokenize, that's all we need to know right now
      # can just load other gateways as-needeed below
      $require_tokenized = 0;
      last;
    }
  }

  warn "REQUIRE TOKENIZED" if $require_tokenized && $debug;

  # upgrade does not call this with autocommit turned on,
  # and autocommit will be ignored if opt queue is set,
  # but might as well be thorough...
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # for retrieving data in chunks
  my $step = 500;
  my $offset = 0;

  ### Tokenize cust_payby

  my @recnums;

CUSTLOOP:
  while (my $custnum = _token_check_next_recnum($dbh,'cust_main',$step,\$offset,\@recnums)) {
    my $cust_main = FS::cust_main->by_key($custnum);
    my $payment_gateway;
    foreach my $cust_payby ($cust_main->cust_payby('CARD','DCRD')) {

      # see if it's already tokenized
      if ($cust_payby->tokenized) {
        warn "cust_payby ".$cust_payby->get($cust_payby->primary_key)." already tokenized" if $debug;
        next;
      }

      if ($require_tokenized && $opt{'daily'}) {
        $log->critical("Untokenized card number detected in cust_payby ".$cust_payby->custpaybynum);
        $dbh->commit or die $dbh->errstr; # commit log message
      }

      # only load gateway if we need to, and only need to load it once
      $payment_gateway ||= $cust_main->_payment_gateway({
        'method'  => 'CC',
        'conf'    => $conf,
        'nofatal' => 1, # handle lack of gateway smoothly below
      });
      unless ($payment_gateway) {
        # no reason to have untokenized card numbers saved if no gateway,
        #   but only a problem if we expected everyone to tokenize card numbers
        unless ($require_tokenized) {
          warn "Skipping cust_payby for cust_main ".$cust_main->custnum.", no payment gateway" if $debug;
          next CUSTLOOP; # can skip rest of customer
        }
        my $error = "No gateway found for custnum ".$cust_main->custnum;
        if ($opt{'queue'}) {
          $log->critical($error);
          $dbh->commit or die $dbh->errstr; # commit error message
          next; # not next CUSTLOOP, want to record error for every cust_payby
        }
        $dbh->rollback if $oldAutoCommit;
        die $error;
      }

      my $info = _token_check_gateway_info($cache,$payment_gateway);
      unless (ref($info)) {
        # only throws error if Business::OnlinePayment won't load,
        #   which is just cause to abort this whole process, even if queue
        $dbh->rollback if $oldAutoCommit;
        die $info; # error message
      }
      # no fail here--a configured gateway can't tokenize, so be it
      unless ($info->{'can_tokenize'}) {
        warn "Skipping ".$cust_main->custnum." cannot tokenize" if $debug;
        next;
      }

      # time to tokenize
      $cust_payby = $cust_payby->select_for_update;
      my %tokenopts = (
        'payment_gateway' => $payment_gateway,
        'cust_payby'      => $cust_payby,
      );
      my $error = $cust_main->realtime_tokenize(\%tokenopts);
      if ($cust_payby->tokenized) { # implies no error
        $error = $cust_payby->replace;
      } else {
        $error ||= 'Unknown error';
      }
      if ($error) {
        $error = "Error tokenizing cust_payby ".$cust_payby->custpaybynum.": ".$error;
        if ($opt{'queue'}) {
          $log->critical($error);
          $dbh->commit or die $dbh->errstr; # commit log message, release mutex
          next; # not next CUSTLOOP, want to record error for every cust_payby
        }
        $dbh->rollback if $oldAutoCommit;
        die $error;
      }
      $dbh->commit or die $dbh->errstr if $opt{'queue'}; # release mutex
      warn "TOKENIZED cust_payby ".$cust_payby->get($cust_payby->primary_key) if $debug;
    }
    warn "cust_payby upgraded for custnum ".$cust_main->custnum if $debug;

  }

  ### Tokenize/mask transaction tables

  # allow tokenization of closed cust_pay/cust_refund records
  local $FS::payinfo_Mixin::allow_closed_replace = 1;

  # grep assistance:
  #   $cust_pay_pending->replace, $cust_pay->replace, $cust_pay_void->replace, $cust_refund->replace all run here
  foreach my $table ( qw(cust_pay_pending cust_pay cust_pay_void cust_refund) ) {
    warn "Checking $table" if $debug;

    # FS::Cursor does not seem to work over multiple commits (gives cursor not found errors)
    # loading only record ids, then loading individual records one at a time
    my $tclass = 'FS::'.$table;
    $offset = 0;
    @recnums = ();

    while (my $recnum = _token_check_next_recnum($dbh,$table,$step,\$offset,\@recnums)) {
      my $record = $tclass->by_key($recnum);
      if (FS::cust_main::Billing_Realtime->tokenized($record->payinfo)) {
        warn "Skipping tokenized record for $table ".$record->get($record->primary_key) if $debug;
        next;
      }
      if (!$record->payinfo) { #shouldn't happen, but at least it's not a card number
        warn "Skipping blank payinfo for $table ".$record->get($record->primary_key) if $debug;
        next;
      }
      if ($record->payinfo =~ /N\/A/) { # ??? Not sure why we do this, but it's not a card number
        warn "Skipping NA payinfo for $table ".$record->get($record->primary_key) if $debug;
        next;
      }

      if ($require_tokenized && $opt{'daily'}) {
        $log->critical("Untokenized card number detected in $table ".$record->get($record->primary_key));
        $dbh->commit or die $dbh->errstr; # commit log message
      }

      my $cust_main = $record->cust_main;
      if (!$cust_main) {
        # might happen for cust_pay_pending from failed verify records,
        #   in which case we attempt tokenization without cust_main
        # everything else should absolutely have a cust_main
        if ($table eq 'cust_pay_pending' and !$record->custnum ) {
          # override the usual safety check and allow the record to be
          # updated even without a custnum.
          $record->set('custnum_pending', 1);
        } else {
          my $error = "Could not load cust_main for $table ".$record->get($record->primary_key);
          if ($opt{'queue'}) {
            $log->critical($error);
            $dbh->commit or die $dbh->errstr; # commit log message
            next;
          }
          $dbh->rollback if $oldAutoCommit;
          die $error;
        }
      }

      my $gateway;

      # use the gatewaynum specified by the record if possible
      $gateway = FS::payment_gateway->by_key_with_namespace(
        'gatewaynum' => $record->gatewaynum,
      ) if $record->gateway;

      # otherwise use the cust agent gateway if possible (which realtime_refund_bop would do)
      # otherwise just use default gateway
      unless ($gateway) {

        $gateway = $cust_main 
                 ? $cust_main->agent->payment_gateway
                 : FS::payment_gateway->default_gateway;

        # check for processor mismatch
        unless ($table eq 'cust_pay_pending') { # has no processor table
          if (my $processor = $record->processor) {

            my $conf_processor = $gateway->gateway_module;
            my %bop_options = $gateway->gatewaynum
                            ? $gateway->options
                            : @{ $gateway->get('options') };

            # this is the same standard used by realtime_refund_bop
            unless (
              ($processor eq $conf_processor) ||
              (($conf_processor eq 'CardFortress') && ($processor eq $bop_options{'gateway'}))
            ) {

              # processors don't match, so refund already cannot be run on this object,
              # regardless of what we do now...
              # but unless we gotta tokenize everything, just leave well enough alone
              unless ($require_tokenized) {
                warn "Skipping mismatched processor for $table ".$record->get($record->primary_key) if $debug;
                next;
              }
              ### no error--we'll tokenize using the new gateway, just to remove stored payinfo,
              ### because refunds are already impossible for this record, anyway

            } # end processor mismatch

          } # end record has processor
        } # end not cust_pay_pending

      }

      # means no default gateway, no promise to tokenize, can skip
      unless ($gateway) {
        warn "Skipping missing gateway for $table ".$record->get($record->primary_key) if $debug;
        next;
      }

      my $info = _token_check_gateway_info($cache,$gateway);
      unless (ref($info)) {
        # only throws error if Business::OnlinePayment won't load,
        #   which is just cause to abort this whole process, even if queue
        $dbh->rollback if $oldAutoCommit;
        die $info; # error message
      }

      # a configured gateway can't tokenize, move along
      unless ($info->{'can_tokenize'}) {
        warn "Skipping, cannot tokenize $table ".$record->get($record->primary_key) if $debug;
        next;
      }

      warn "ATTEMPTING GATEWAY-ONLY TOKENIZE" if $debug && !$cust_main;

      # if we got this far, time to mutex
      $record->select_for_update;

      # no clear record of name/address/etc used for transaction,
      # but will load name/phone/id from customer if run as an object method,
      # so we try that if we can
      my %tokenopts = (
        'payment_gateway' => $gateway,
        'method'          => 'CC',
        'payinfo'         => $record->payinfo,
        'paydate'         => $record->paydate,
      );
      my $error = $cust_main
                ? $cust_main->realtime_tokenize(\%tokenopts)
                : FS::cust_main::Billing_Realtime->realtime_tokenize(\%tokenopts);
      if (FS::cust_main::Billing_Realtime->tokenized($tokenopts{'payinfo'})) { # implies no error
        $record->payinfo($tokenopts{'payinfo'});
        $error = $record->replace;
      } else {
        $error ||= 'Unknown error';
      }
      if ($error) {
        $error = "Error tokenizing $table ".$record->get($record->primary_key).": ".$error;
        if ($opt{'queue'}) {
          $log->critical($error);
          $dbh->commit or die $dbh->errstr; # commit log message, release mutex
          next;
        }
        $dbh->rollback if $oldAutoCommit;
        die $error;
      }
      $dbh->commit or die $dbh->errstr if $opt{'queue'}; # release mutex
      warn "TOKENIZED $table ".$record->get($record->primary_key) if $debug;

    } # end record loop
  } # end table loop

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return '';
}

# not a method!
sub _token_check_next_recnum {
  my ($dbh,$table,$step,$offset,$recnums) = @_;
  my $recnum = shift @$recnums;
  return $recnum if $recnum;
  my $tclass = 'FS::'.$table;
  my $sth = $dbh->prepare('SELECT '.$tclass->primary_key.' FROM '.$table.' ORDER BY '.$tclass->primary_key.' LIMIT '.$step.' OFFSET '.$$offset) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;
  my @recnums;
  while (my $rec = $sth->fetchrow_hashref) {
    push @$recnums, $rec->{$tclass->primary_key};
  }
  $sth->finish();
  $$offset += $step;
  return shift @$recnums;
}

# not a method!
sub _token_check_gateway_info {
  my ($cache,$payment_gateway) = @_;

  return $cache->{$payment_gateway->gateway_module}
    if $cache->{$payment_gateway->gateway_module};

  my $info = {};
  $cache->{$payment_gateway->gateway_module} = $info;

  my $namespace = $payment_gateway->gateway_namespace;
  return $info unless $namespace eq 'Business::OnlinePayment';
  $info->{'is_bop'} = 1;

  # only need to load this once,
  # don't want to load if nothing is_bop
  unless ($cache->{'Business::OnlinePayment'}) {
    eval "use $namespace";  
    return "Error initializing Business:OnlinePayment: ".$@ if $@;
    $cache->{'Business::OnlinePayment'} = 1;
  }

  my $transaction = new $namespace( $payment_gateway->gateway_module,
                                    _bop_options({ 'payment_gateway' => $payment_gateway }),
                                  );

  return $info unless $transaction->can('info');
  $info->{'can_info'} = 1;

  my %supported_actions = $transaction->info('supported_actions');
  $info->{'can_tokenize'} = 1
    if $supported_actions{'CC'}
      && grep /^Tokenize$/, @{$supported_actions{'CC'}};

  # not using this any more, but for future reference...
  $info->{'void_requires_card'} = 1
    if $transaction->info('CC_void_requires_card');

  return $info;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_main::Billing>

=cut

1;
