package FS::cust_bill;

use strict;
use vars qw( @ISA $conf $money_char );
use vars qw( $lpr $invoice_from $smtpmachine );
use vars qw( $processor );
use vars qw( $xaction $E_NoErr );
use vars qw( $bop_processor $bop_login $bop_password $bop_action @bop_options );
use vars qw( $invoice_lines @buf ); #yuck
use Date::Format;
use Mail::Internet;
use Mail::Header;
use Text::Template;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_bill_pkg;
use FS::cust_credit;
use FS::cust_pay;
use FS::cust_pkg;
use FS::cust_credit_bill;
use FS::cust_pay_batch;
use FS::cust_bill_event;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_bill'} = sub { 

  $conf = new FS::Conf;

  $money_char = $conf->config('money_char') || '$';  

  $lpr = $conf->config('lpr');
  $invoice_from = $conf->config('invoice_from');
  $smtpmachine = $conf->config('smtpmachine');

  if ( $conf->exists('cybercash3.2') ) {
    require CCMckLib3_2;
      #qw($MCKversion %Config InitConfig CCError CCDebug CCDebug2);
    require CCMckDirectLib3_2;
      #qw(SendCC2_1Server);
    require CCMckErrno3_2;
      #qw(MCKGetErrorMessage $E_NoErr);
    import CCMckErrno3_2 qw($E_NoErr);

    my $merchant_conf;
    ($merchant_conf,$xaction)= $conf->config('cybercash3.2');
    my $status = &CCMckLib3_2::InitConfig($merchant_conf);
    if ( $status != $E_NoErr ) {
      warn "CCMckLib3_2::InitConfig error:\n";
      foreach my $key (keys %CCMckLib3_2::Config) {
        warn "  $key => $CCMckLib3_2::Config{$key}\n"
      }
      my($errmsg) = &CCMckErrno3_2::MCKGetErrorMessage($status);
      die "CCMckLib3_2::InitConfig fatal error: $errmsg\n";
    }
    $processor='cybercash3.2';
  } elsif ( $conf->exists('business-onlinepayment') ) {
    ( $bop_processor,
      $bop_login,
      $bop_password,
      $bop_action,
      @bop_options
    ) = $conf->config('business-onlinepayment');
    $bop_action ||= 'normal authorization';
    eval "use Business::OnlinePayment";  
    $processor="Business::OnlinePayment::$bop_processor";
  }

};

=head1 NAME

FS::cust_bill - Object methods for cust_bill records

=head1 SYNOPSIS

  use FS::cust_bill;

  $record = new FS::cust_bill \%hash;
  $record = new FS::cust_bill { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ( $total_previous_balance, @previous_cust_bill ) = $record->previous;

  @cust_bill_pkg_objects = $cust_bill->cust_bill_pkg;

  ( $total_previous_credits, @previous_cust_credit ) = $record->cust_credit;

  @cust_pay_objects = $cust_bill->cust_pay;

  $tax_amount = $record->tax;

  @lines = $cust_bill->print_text;
  @lines = $cust_bill->print_text $time;

=head1 DESCRIPTION

An FS::cust_bill object represents an invoice; a declaration that a customer
owes you money.  The specific charges are itemized as B<cust_bill_pkg> records
(see L<FS::cust_bill_pkg>).  FS::cust_bill inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item invnum - primary key (assigned automatically for new invoices)

=item custnum - customer (see L<FS::cust_main>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item charged - amount of this invoice

=item printed - deprecated

=item closed - books closed flag, empty or `Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice.  To add the invoice to the database, see L<"insert">.
Invoices are normally created by calling the bill method of a customer object
(see L<FS::cust_main>).

=cut

sub table { 'cust_bill'; }

=item insert

Adds this invoice to the database ("Posts" the invoice).  If there is an error,
returns the error, otherwise returns false.

=item delete

Currently unimplemented.  I don't remove invoices because there would then be
no record you ever posted this invoice (which is bad, no?)

=cut

sub delete {
  my $self = shift;
  return "Can't delete closed invoice" if $self->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Only printed may be changed.  printed is normally updated by calling the
collect method of a customer object (see L<FS::cust_main>).

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );
  return "Can't change custnum!" unless $old->custnum == $new->custnum;
  #return "Can't change _date!" unless $old->_date eq $new->_date;
  return "Can't change _date!" unless $old->_date == $new->_date;
  return "Can't change charged!" unless $old->charged == $new->charged;

  $new->SUPER::replace($old);
}

=item check

Checks all fields to make sure this is a valid invoice.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('invnum')
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
    || $self->ut_numbern('printed')
    || $self->ut_enum('closed', [ '', 'Y' ])
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->printed(0) if $self->printed eq '';

  ''; #no error
}

=item previous

Returns a list consisting of the total previous balance for this customer, 
followed by the previous outstanding invoices (as FS::cust_bill objects also).

=cut

sub previous {
  my $self = shift;
  my $total = 0;
  my @cust_bill = sort { $a->_date <=> $b->_date }
    grep { $_->owed != 0 && $_->_date < $self->_date }
      qsearch( 'cust_bill', { 'custnum' => $self->custnum } ) 
  ;
  foreach ( @cust_bill ) { $total += $_->owed; }
  $total, @cust_bill;
}

=item cust_bill_pkg

Returns the line items (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearch( 'cust_bill_pkg', { 'invnum' => $self->invnum } );
}

=item cust_bill_event

Returns the completed invoice events (see L<FS::cust_bill_event>) for this
invoice.

=cut

sub cust_bill_event {
  my $self = shift;
  qsearch( 'cust_bill_event', { 'invnum' => $self->invnum } );
}


=item cust_main

Returns the customer (see L<FS::cust_main>) for this invoice.

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item cust_credit

Depreciated.  See the cust_credited method.

 #Returns a list consisting of the total previous credited (see
 #L<FS::cust_credit>) and unapplied for this customer, followed by the previous
 #outstanding credits (FS::cust_credit objects).

=cut

sub cust_credit {
  use Carp;
  croak "FS::cust_bill->cust_credit depreciated; see ".
        "FS::cust_bill->cust_credit_bill";
  #my $self = shift;
  #my $total = 0;
  #my @cust_credit = sort { $a->_date <=> $b->_date }
  #  grep { $_->credited != 0 && $_->_date < $self->_date }
  #    qsearch('cust_credit', { 'custnum' => $self->custnum } )
  #;
  #foreach (@cust_credit) { $total += $_->credited; }
  #$total, @cust_credit;
}

=item cust_pay

Depreciated.  See the cust_bill_pay method.

#Returns all payments (see L<FS::cust_pay>) for this invoice.

=cut

sub cust_pay {
  use Carp;
  croak "FS::cust_bill->cust_pay depreciated; see FS::cust_bill->cust_bill_pay";
  #my $self = shift;
  #sort { $a->_date <=> $b->_date }
  #  qsearch( 'cust_pay', { 'invnum' => $self->invnum } )
  #;
}

=item cust_bill_pay

Returns all payment applications (see L<FS::cust_bill_pay>) for this invoice.

=cut

sub cust_bill_pay {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_bill_pay', { 'invnum' => $self->invnum } );
}

=item cust_credited

Returns all applied credits (see L<FS::cust_credit_bill>) for this invoice.

=cut

sub cust_credited {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_credit_bill', { 'invnum' => $self->invnum } )
  ;
}

=item tax

Returns the tax amount (see L<FS::cust_bill_pkg>) for this invoice.

=cut

sub tax {
  my $self = shift;
  my $total = 0;
  my @taxlines = qsearch( 'cust_bill_pkg', { 'invnum' => $self->invnum ,
                                             'pkgnum' => 0 } );
  foreach (@taxlines) { $total += $_->setup; }
  $total;
}

=item owed

Returns the amount owed (still outstanding) on this invoice, which is charged
minus all payment applications (see L<FS::cust_bill_pay>) and credit
applications (see L<FS::cust_credit_bill>).

=cut

sub owed {
  my $self = shift;
  my $balance = $self->charged;
  $balance -= $_->amount foreach ( $self->cust_bill_pay );
  $balance -= $_->amount foreach ( $self->cust_credited );
  $balance = sprintf( "%.2f", $balance);
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

=item send

Sends this invoice to the destinations configured for this customer: send
emails or print.  See L<FS::cust_main_invoice>.

=cut

sub send {
  my($self,$template) = @_;

  #my @print_text = $cust_bill->print_text; #( date )
  my @invoicing_list = $self->cust_main->invoicing_list;
  if ( grep { $_ ne 'POST' } @invoicing_list ) { #email invoice
    #false laziness w/FS::cust_pay::delete & fs_signup_server && ::realtime_card
    #$ENV{SMTPHOSTS} = $smtpmachine;
    $ENV{MAILADDRESS} = $invoice_from;
    my $header = new Mail::Header ( [
      "From: $invoice_from",
      "To: ". join(', ', grep { $_ ne 'POST' } @invoicing_list ),
      "Sender: $invoice_from",
      "Reply-To: $invoice_from",
      "Date: ". time2str("%a, %d %b %Y %X %z", time),
      "Subject: Invoice",
    ] );
    my $message = new Mail::Internet (
      'Header' => $header,
      'Body' => [ $self->print_text('', $template) ], #( date)
    );
    $!=0;
    $message->smtpsend( Host => $smtpmachine )
      or $message->smtpsend( Host => $smtpmachine, Debug => 1 )
        or return "(customer # ". $self->custnum. ") can't send invoice email".
                  " to ". join(', ', grep { $_ ne 'POST' } @invoicing_list ).
                  " via server $smtpmachine with SMTP: $!";

  #} elsif ( grep { $_ eq 'POST' } @invoicing_list ) {
  } elsif ( ! @invoicing_list || grep { $_ eq 'POST' } @invoicing_list ) {
    open(LPR, "|$lpr")
      or return "Can't open pipe to $lpr: $!";
    print LPR $self->print_text; #( date )
    close LPR
      or return $! ? "Error closing $lpr: $!"
                   : "Exit status $? from $lpr";
  }

  '';

}

=item comp

Pays this invoice with a compliemntary payment.  If there is an error,
returns the error, otherwise returns false.

=cut

sub comp {
  my $self = shift;
  my $cust_pay = new FS::cust_pay ( {
    'invnum'   => $self->invnum,
    'paid'     => $self->owed,
    '_date'    => '',
    'payby'    => 'COMP',
    'payinfo'  => $self->cust_main->payinfo,
    'paybatch' => '',
  } );
  $cust_pay->insert;
}

=item realtime_card

Attempts to pay this invoice with a Business::OnlinePayment realtime gateway.
See http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment
for supproted processors.

=cut

sub realtime_card {
  my $self = shift;
  my $cust_main = $self->cust_main;
  my $amount = $self->owed;

  unless ( $processor =~ /^Business::OnlinePayment::(.*)$/ ) {
    return "Real-time card processing not enabled (processor $processor)";
  }
  my $bop_processor = $1; #hmm?

  my $address = $cust_main->address1;
  $address .= ", ". $cust_main->address2 if $cust_main->address2;

  #fix exp. date
  #$cust_main->paydate =~ /^(\d+)\/\d*(\d{2})$/;
  $cust_main->paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
  my $exp = "$2/$1";

  my($payname, $payfirst, $paylast);
  if ( $cust_main->payname ) {
    $payname = $cust_main->payname;
    $payname =~ /^\s*([\w \,\.\-\']*)?\s+([\w\,\.\-\']+)$/
      or do {
              #$dbh->rollback if $oldAutoCommit;
              return "Illegal payname $payname";
            };
    ($payfirst, $paylast) = ($1, $2);
  } else {
    $payfirst = $cust_main->getfield('first');
    $paylast = $cust_main->getfield('first');
    $payname =  "$payfirst $paylast";
  }

  my @invoicing_list = grep { $_ ne 'POST' } $cust_main->invoicing_list;
  if ( $conf->exists('emailinvoiceauto')
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $cust_main->default_invoicing_list;
  }
  my $email = $invoicing_list[0];

  my( $action1, $action2 ) = split(/\s*\,\s*/, $bop_action );

  my $description = 'Internet Services';
  if ( $conf->exists('business-onlinepayment-description') ) {
    my $dtempl = $conf->config('business-onlinepayment-description');

    my $agent_obj = $cust_main->agent
      or die "can't retreive agent for $cust_main (agentnum ".
             $cust_main->agentnum. ")";
    my $agent = $agent_obj->agent;
    my $pkgs = join(', ',
      map { $_->cust_pkg->part_pkg->pkg }
        grep { $_->pkgnum } $self->cust_bill_pkg
    );
    $description = eval qq("$dtempl");

  }
  
  my $transaction =
    new Business::OnlinePayment( $bop_processor, @bop_options );
  $transaction->content(
    'type'           => 'CC',
    'login'          => $bop_login,
    'password'       => $bop_password,
    'action'         => $action1,
    'description'    => $description,
    'amount'         => $amount,
    'invoice_number' => $self->invnum,
    'customer_id'    => $self->custnum,
    'last_name'      => $paylast,
    'first_name'     => $payfirst,
    'name'           => $payname,
    'address'        => $address,
    'city'           => $cust_main->city,
    'state'          => $cust_main->state,
    'zip'            => $cust_main->zip,
    'country'        => $cust_main->country,
    'card_number'    => $cust_main->payinfo,
    'expiration'     => $exp,
    'referer'        => 'http://cleanwhisker.420.am/',
    'email'          => $email,
  );
  $transaction->submit();

  if ( $transaction->is_success() && $action2 ) {
    my $auth = $transaction->authorization;
    my $ordernum = $transaction->order_number;
    #warn "********* $auth ***********\n";
    #warn "********* $ordernum ***********\n";
    my $capture =
      new Business::OnlinePayment( $bop_processor, @bop_options );

    $capture->content(
      action         => $action2,
      login          => $bop_login,
      password       => $bop_password,
      order_number   => $ordernum,
      amount         => $amount,
      authorization  => $auth,
      description    => $description,
    );

    $capture->submit();

    unless ( $capture->is_success ) {
      my $e = "Authorization sucessful but capture failed, invnum #".
              $self->invnum. ': '.  $capture->result_code.
              ": ". $capture->error_message;
      warn $e;
      return $e;
    }

  }

  if ( $transaction->is_success() ) {

    my $cust_pay = new FS::cust_pay ( {
       'invnum'   => $self->invnum,
       'paid'     => $amount,
       '_date'     => '',
       'payby'    => 'CARD',
       'payinfo'  => $cust_main->payinfo,
       'paybatch' => "$processor:". $transaction->authorization,
    } );
    my $error = $cust_pay->insert;
    if ( $error ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card debited but database not updated - '.
              'error applying payment, invnum #' . $self->invnum.
              " ($processor): $error";
      warn $e;
      return $e;
    } else {
      return '';
    }
  #} elsif ( $options{'report_badcard'} ) {
  } else {

    my $perror = "$processor error, invnum #". $self->invnum. ': '.
                 $transaction->result_code. ": ". $transaction->error_message;

    if ( $conf->exists('emaildecline')
         && grep { $_ ne 'POST' } $cust_main->invoicing_list
    ) {
      my @templ = $conf->config('declinetemplate');
      my $template = new Text::Template (
        TYPE   => 'ARRAY',
        SOURCE => [ map "$_\n", @templ ],
      ) or return "($perror) can't create template: $Text::Template::ERROR";
      $template->compile()
        or return "($perror) can't compile template: $Text::Template::ERROR";

      my $error = $transaction->error_message;

      #false laziness w/FS::cust_pay::delete & fs_signup_server && ::send
      $ENV{MAILADDRESS} = $invoice_from;
      my $header = new Mail::Header ( [
        "From: $invoice_from",
        "To: ". join(', ', grep { $_ ne 'POST' } $cust_main->invoicing_list ),
        "Sender: $invoice_from",
        "Reply-To: $invoice_from",
        "Date: ". time2str("%a, %d %b %Y %X %z", time),
        "Subject: Your credit card could not be processed",
      ] );
      my $message = new Mail::Internet (
        'Header' => $header,
        'Body' => [ $template->fill_in() ],
      );
      $!=0;
      $message->smtpsend( Host => $smtpmachine )
        or $message->smtpsend( Host => $smtpmachine, Debug => 1 )
          or return "($perror) (customer # ". $self->custnum.
            ") can't send card decline email to ".
            join(', ', grep { $_ ne 'POST' } $cust_main->invoicing_list ).
            " via server $smtpmachine with SMTP: $!";
    }
  
    return $perror;
  }

}

=item realtime_card_cybercash

Attempts to pay this invoice with the CyberCash CashRegister realtime gateway.

=cut

sub realtime_card_cybercash {
  my $self = shift;
  my $cust_main = $self->cust_main;
  my $amount = $self->owed;

  return "CyberCash CashRegister real-time card processing not enabled!"
    unless $processor eq 'cybercash3.2';

  my $address = $cust_main->address1;
  $address .= ", ". $cust_main->address2 if $cust_main->address2;

  #fix exp. date
  #$cust_main->paydate =~ /^(\d+)\/\d*(\d{2})$/;
  $cust_main->paydate =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
  my $exp = "$2/$1";

  #

  my $paybatch = $self->invnum. 
                  '-' . time2str("%y%m%d%H%M%S", time);

  my $payname = $cust_main->payname ||
                $cust_main->getfield('first').' '.$cust_main->getfield('last');

  my $country = $cust_main->country eq 'US' ? 'USA' : $cust_main->country;

  my @full_xaction = ( $xaction,
    'Order-ID'     => $paybatch,
    'Amount'       => "usd $amount",
    'Card-Number'  => $cust_main->getfield('payinfo'),
    'Card-Name'    => $payname,
    'Card-Address' => $address,
    'Card-City'    => $cust_main->getfield('city'),
    'Card-State'   => $cust_main->getfield('state'),
    'Card-Zip'     => $cust_main->getfield('zip'),
    'Card-Country' => $country,
    'Card-Exp'     => $exp,
  );

  my %result;
  %result = &CCMckDirectLib3_2::SendCC2_1Server(@full_xaction);
  
  if ( $result{'MStatus'} eq 'success' ) { #cybercash smps v.2 or 3
    my $cust_pay = new FS::cust_pay ( {
       'invnum'   => $self->invnum,
       'paid'     => $amount,
       '_date'     => '',
       'payby'    => 'CARD',
       'payinfo'  => $cust_main->payinfo,
       'paybatch' => "$processor:$paybatch",
    } );
    my $error = $cust_pay->insert;
    if ( $error ) {
      # gah, even with transactions.
      my $e = 'WARNING: Card debited but database not updated - '.
              'error applying payment, invnum #' . $self->invnum.
              " (CyberCash Order-ID $paybatch): $error";
      warn $e;
      return $e;
    } else {
      return '';
    }
#  } elsif ( $result{'Mstatus'} ne 'failure-bad-money'
#            || $options{'report_badcard'}
#          ) {
  } else {
     return 'Cybercash error, invnum #' . 
       $self->invnum. ':'. $result{'MErrMsg'};
  }

}

=item batch_card

Adds a payment for this invoice to the pending credit card batch (see
L<FS::cust_pay_batch>).

=cut

sub batch_card {
  my $self = shift;
  my $cust_main = $self->cust_main;

  my $cust_pay_batch = new FS::cust_pay_batch ( {
    'invnum'   => $self->getfield('invnum'),
    'custnum'  => $cust_main->getfield('custnum'),
    'last'     => $cust_main->getfield('last'),
    'first'    => $cust_main->getfield('first'),
    'address1' => $cust_main->getfield('address1'),
    'address2' => $cust_main->getfield('address2'),
    'city'     => $cust_main->getfield('city'),
    'state'    => $cust_main->getfield('state'),
    'zip'      => $cust_main->getfield('zip'),
    'country'  => $cust_main->getfield('country'),
    'trancode' => 77,
    'cardnum'  => $cust_main->getfield('payinfo'),
    'exp'      => $cust_main->getfield('paydate'),
    'payname'  => $cust_main->getfield('payname'),
    'amount'   => $self->owed,
  } );
  $cust_pay_batch->insert;

}

=item print_text [TIME];

Returns an text invoice, as a list of lines.

TIME an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

sub print_text {

  my( $self, $today, $template ) = @_;
  $today ||= time;
#  my $invnum = $self->invnum;
  my $cust_main = qsearchs('cust_main', { 'custnum', $self->custnum } );
  $cust_main->payname( $cust_main->first. ' '. $cust_main->getfield('last') )
    unless $cust_main->payname;

  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
#  my( $cr_total, @cr_cust_credit ) = $self->cust_credit; #credits
  #my $balance_due = $self->owed + $pr_total - $cr_total;
  my $balance_due = $self->owed + $pr_total;

  #my @collect = ();
  #my($description,$amount);
  @buf = ();

  #previous balance
  foreach ( @pr_cust_bill ) {
    push @buf, [
      "Previous Balance, Invoice #". $_->invnum. 
                 " (". time2str("%x",$_->_date). ")",
      $money_char. sprintf("%10.2f",$_->owed)
    ];
  }
  if (@pr_cust_bill) {
    push @buf,['','-----------'];
    push @buf,[ 'Total Previous Balance',
                $money_char. sprintf("%10.2f",$pr_total ) ];
    push @buf,['',''];
  }

  #new charges
  foreach ( $self->cust_bill_pkg ) {

    if ( $_->pkgnum ) {

      my($cust_pkg)=qsearchs('cust_pkg', { 'pkgnum', $_->pkgnum } );
      my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->pkgpart});
      my($pkg)=$part_pkg->pkg;

      if ( $_->setup != 0 ) {
        push @buf, [ "$pkg Setup", $money_char. sprintf("%10.2f",$_->setup) ];
        push @buf,
          map { [ "  ". $_->[0]. ": ". $_->[1], '' ] } $cust_pkg->labels;
      }

      if ( $_->recur != 0 ) {
        push @buf, [
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")",
          $money_char. sprintf("%10.2f",$_->recur)
        ];
        push @buf,
          map { [ "  ". $_->[0]. ": ". $_->[1], '' ] } $cust_pkg->labels;
      }

    } else { #pkgnum Tax
      push @buf,["Tax", $money_char. sprintf("%10.2f",$_->setup) ] 
        if $_->setup != 0;
    }
  }

  push @buf,['','-----------'];
  push @buf,['Total New Charges',
             $money_char. sprintf("%10.2f",$self->charged) ];
  push @buf,['',''];

  push @buf,['','-----------'];
  push @buf,['Total Charges',
             $money_char. sprintf("%10.2f",$self->charged + $pr_total) ];
  push @buf,['',''];

  #credits
  foreach ( $self->cust_credited ) {

    #something more elaborate if $_->amount ne $_->cust_credit->credited ?

    my $reason = substr($_->cust_credit->reason,0,32);
    $reason .= '...' if length($reason) < length($_->cust_credit->reason);
    $reason = " ($reason) " if $reason;
    push @buf,[
      "Credit #". $_->crednum. " (". time2str("%x",$_->cust_credit->_date) .")".
        $reason,
      $money_char. sprintf("%10.2f",$_->amount)
    ];
  }
  #foreach ( @cr_cust_credit ) {
  #  push @buf,[
  #    "Credit #". $_->crednum. " (" . time2str("%x",$_->_date) .")",
  #    $money_char. sprintf("%10.2f",$_->credited)
  #  ];
  #}

  #get & print payments
  foreach ( $self->cust_bill_pay ) {

    #something more elaborate if $_->amount ne ->cust_pay->paid ?

    push @buf,[
      "Payment received ". time2str("%x",$_->cust_pay->_date ),
      $money_char. sprintf("%10.2f",$_->amount )
    ];
  }

  #balance due
  push @buf,['','-----------'];
  push @buf,['Balance Due', $money_char. 
    sprintf("%10.2f", $balance_due ) ];

  #create the template
  my $templatefile = 'invoice_template';
  $templatefile .= "_$template" if $template;
  my @invoice_template = $conf->config($templatefile)
  or die "cannot load config file $templatefile";
  $invoice_lines = 0;
  my $wasfunc = 0;
  foreach ( grep /invoice_lines\(\d+\)/, @invoice_template ) { #kludgy
    /invoice_lines\((\d+)\)/;
    $invoice_lines += $1;
    $wasfunc=1;
  }
  die "no invoice_lines() functions in template?" unless $wasfunc;
  my $invoice_template = new Text::Template (
    TYPE   => 'ARRAY',
    SOURCE => [ map "$_\n", @invoice_template ],
  ) or die "can't create new Text::Template object: $Text::Template::ERROR";
  $invoice_template->compile()
    or die "can't compile template: $Text::Template::ERROR";

  #setup template variables
  package FS::cust_bill::_template; #!
  use vars qw( $invnum $date $page $total_pages @address $overdue @buf );

  $invnum = $self->invnum;
  $date = $self->_date;
  $page = 1;

  if ( $FS::cust_bill::invoice_lines ) {
    $total_pages =
      int( scalar(@FS::cust_bill::buf) / $FS::cust_bill::invoice_lines );
    $total_pages++
      if scalar(@FS::cust_bill::buf) % $FS::cust_bill::invoice_lines;
  } else {
    $total_pages = 1;
  }

  #format address (variable for the template)
  my $l = 0;
  @address = ( '', '', '', '', '', '' );
  package FS::cust_bill; #!
  $FS::cust_bill::_template::address[$l++] =
    $cust_main->payname.
      ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo
        ? " (P.O. #". $cust_main->payinfo. ")"
        : ''
      )
  ;
  $FS::cust_bill::_template::address[$l++] = $cust_main->company
    if $cust_main->company;
  $FS::cust_bill::_template::address[$l++] = $cust_main->address1;
  $FS::cust_bill::_template::address[$l++] = $cust_main->address2
    if $cust_main->address2;
  $FS::cust_bill::_template::address[$l++] =
    $cust_main->city. ", ". $cust_main->state. "  ".  $cust_main->zip;
  $FS::cust_bill::_template::address[$l++] = $cust_main->country
    unless $cust_main->country eq 'US';

	#  #overdue? (variable for the template)
	#  $FS::cust_bill::_template::overdue = ( 
	#    $balance_due > 0
	#    && $today > $self->_date 
	##    && $self->printed > 1
	#    && $self->printed > 0
	#  );

  #and subroutine for the template

  sub FS::cust_bill::_template::invoice_lines {
    my $lines = shift or return @buf;
    map { 
      scalar(@buf) ? shift @buf : [ '', '' ];
    }
    ( 1 .. $lines );
  }


  #and fill it in
  $FS::cust_bill::_template::page = 1;
  my $lines;
  my @collect;
  while (@buf) {
    push @collect, split("\n",
      $invoice_template->fill_in( PACKAGE => 'FS::cust_bill::_template' )
    );
    $FS::cust_bill::_template::page++;
  }

  map "$_\n", @collect;

}

=back

=head1 VERSION

$Id: cust_bill.pm,v 1.32 2002-04-16 22:56:58 ivan Exp $

=head1 BUGS

The delete method.

print_text formatting (and some logic :/) is in source, but needs to be
slurped in from a file.  Also number of lines ($=).

missing print_ps for a nice postscript copy (maybe HylaFAX-cover-page-style
or something similar so the look can be completely customized?)

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill_pay>, L<FS::cust_pay>,
L<FS::cust_bill_pkg>, L<FS::cust_bill_credit>, schema.html from the base
documentation.

=cut

1;

