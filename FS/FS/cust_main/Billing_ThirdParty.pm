package FS::cust_main::Billing_ThirdParty;

use strict;
use vars qw( $DEBUG $me );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_pay;
use FS::cust_pay_pending;

$DEBUG = 0;
$me = '[FS::cust_main::Billing_ThirdParty]';
# arguably doesn't even belong under cust_main...

=head1 METHODS

=over 4

=item create_payment OPTIONS

Create a pending payment for a third-party gateway.  OPTIONS must include:
- method: a Business::OnlineThirdPartyPayment method argument.  Currently 
  only supports PAYPAL.
- amount: a decimal amount.  Unlike in Billing_Realtime, there is NO default.
- session_id: the customer's self-service session ID.

and may optionally include:
- invnum: the invoice that this payment will apply to
- pkgnum: the package balance that this payment will apply to.
- description: the transaction description for the gateway.
- payip: the IP address the payment is initiated from

On failure, returns a simple string error message.  On success, returns 
a hashref of 'url' => the URL to redirect the user to to complete payment,
and optionally 'post_params' => a hashref of name/value pairs to be POSTed
to that URL.

=cut

my @methods = qw(PAYPAL CC);
my %method2payby = ( 'PAYPAL' => 'PPAL', 'CC' => 'MCRD' );

sub create_payment {
  my $self = shift;
  my %opt = @_;

  # avoid duplicating this--we just need description and invnum
  my $defaults;
  $self->_bop_defaults($defaults);
  
  my $method = $opt{'method'} or return 'method required';
  my $amount = $opt{'amount'} or return 'amount required';
  return "unknown method '$method'" unless grep {$_ eq $method} @methods;
  return "amount must be > 0" unless $amount > 0;
  return "session_id required" unless length($opt{'session_id'});

  my $gateway = $self->agent->payment_gateway(
    method      => $method,
    nofatal     => 1,
    thirdparty  => 1,
  );
  return "no third-party gateway enabled for method $method" if !$gateway;

  # create pending record
  $self->select_for_update;
  my @pending = qsearch('cust_pay_pending', {
      'custnum' => $self->custnum,
      'status'  => { op=>'!=', value=>'done' }
  });

  # if there are pending payments in the 'thirdparty' state,
  # we can safely remove them
  foreach (@pending) {
    if ( $_->status eq 'thirdparty' ) {
      my $error = $_->delete;
      return "Error deleting unfinished payment #".
        $_->paypendingnum . ": $error\n" if $error;
    } else {
      return "A payment is already being processed for this customer.";
    }
  }

  my $cpp = FS::cust_pay_pending->new({
      'custnum'         => $self->custnum,
      'status'          => 'new',
      'gatewaynum'      => $gateway->gatewaynum,
      'paid'            => sprintf('%.2f',$opt{'amount'}),
      'payby'           => $method2payby{ $opt{'method'} },
      'pkgnum'          => $opt{'pkgnum'},
      'invnum'          => $opt{'invnum'} || $defaults->{'invnum'},
      'session_id'      => $opt{'session_id'},
  });

  my $error = $cpp->insert;
  return $error if $error;

  my $transaction = $gateway->processor;
  # Not included in this content hash:
  # payinfo, paydate, paycvv, any kind of recurring billing indicator,
  # paystate, paytype (account type), stateid, ss, payname
  #
  # Also, unlike bop_realtime, we don't allow the magical %options hash
  # to override the customer's information.  If they need to enter a 
  # different address or something for the billing provider, they can do 
  # that after the redirect.
  my %content = (
    'action'      => 'create',
    'description' => $opt{'description'} || $defaults->{'description'},
    'amount'      => $amount,
    'customer_id' => $self->custnum,
    'email'       => $self->invoicing_list_emailonly_scalar,
    'customer_ip' => $opt{'payip'},
    'first_name'  => $self->first,
    'last_name'   => $self->last,
    'address1'    => $self->address1,
    'address2'    => $self->address2,
    'city'        => $self->city,
    'state'       => $self->state,
    'zip'         => $self->zip,
    'country'     => $self->country,
    'phone'       => ($self->daytime || $self->night),
  );

  {
    local $@;
    eval { $transaction->create(%content) };
    if ( $@ ) {
      warn "ERROR: Executing third-party payment:\n$@\n";
      return { error => $@ };
    }
  }

  if ($transaction->is_success) {
    $cpp->status('thirdparty');
    # for whatever is most identifiable as the "transaction ID"
    $cpp->payinfo($transaction->token);
    # for anything else the transaction needs to remember
    $cpp->statustext($transaction->statustext);
    $error = $cpp->replace;
    return $error if $error;

    return {url => $transaction->redirect,
            post_params => $transaction->post_params};

  } else {
    $cpp->status('done');
    $cpp->statustext($transaction->error_message);
    $error = $cpp->replace;
    return $error if $error;

    return $transaction->error_message;
  }

}

=item execute_payment SESSION_ID, PARAMS

Complete the payment and get the status.  Triggered from the return_url
handler; PARAMS are all of the CGI parameters we received in the redirect.
On failure, returns an error message.  On success, returns a hashref of 
'paynum', 'paid', 'order_number', and 'auth'.

=cut

sub execute_payment {
  my $self = shift;
  my $session_id = shift;
  my %params = @_;

  my $cpp = qsearchs('cust_pay_pending', {
      'session_id'  => uc($session_id),
      'custnum'     => $self->custnum,
      'status'      => 'thirdparty',
  })
    or return 'no payment in process for this session';

  my $gateway = FS::payment_gateway->by_key( $cpp->gatewaynum );
  my $transaction = $gateway->processor;
  $transaction->token($cpp->payinfo);
  $transaction->statustext($cpp->statustext);

  {
    local $@;
    eval { $transaction->execute(%params) };
    if ( $@ ) {
      warn "ERROR: Executing third-party payment:\n$@\n";
      return { error => $@ };
    }
  }

  my $error;

  if ( $transaction->is_success ) {

    $error = $cpp->approve(
                    'processor'     => $gateway->gateway_module,
                    'order_number'  => $transaction->order_number,
                    'auth'          => $transaction->authorization,
                    'payinfo'       => '',
                    'apply'         => 1,
                  );
    return $error if $error;

    return {
      'paynum'        => $cpp->paynum,
      'paid'          => $cpp->paid,
      'order_number'  => $transaction->order_number,
      'auth'          => $transaction->authorization,
    }

  } else {

    my $error = $gateway->gateway_module. " error: ".
      $transaction->error_message;

    my $jobnum = $cpp->jobnum;
    if ( $jobnum ) {
      my $placeholder = FS::queue->by_key($jobnum);

      if ( $placeholder ) {
        my $e = $placeholder->depended_delete || $placeholder->delete;
        warn "error removing provisioning jobs after declined paypendingnum ".
          $cpp->paypendingnum. ": $e\n\n"
          if $e;
      } else {
        warn "error finding job $jobnum for declined paypendingnum ".
          $cpp->paypendingnum. "\n\n";
      }
    }

    # not needed here:
    # the raw HTTP response thing when there's no error message
    # decline notices (the customer has already seen the decline message)

    # set the pending status
    my $e = $cpp->decline($error);
    if ( $e ) {
      $e = "WARNING: payment declined but pending payment not resolved - ".
           "error updating status for pendingnum :".$cpp->paypendingnum.
           ": $e\n\n";
      warn $e;
      $error = "$e ($error)";
    }

    return $error;
  }

}

=item cancel_payment SESSION_ID

Cancel a pending payment attempt.  This just cleans up the cust_pay_pending
record.

=cut

sub cancel_payment {
  my $self = shift;
  my $session_id = shift;
  my $cust_pay_pending = qsearchs('cust_pay_pending', {
      'session_id'  => uc($session_id),
      'status'      => 'thirdparty',
  });
  return { 'error' => $cust_pay_pending->delete };
}

1;

