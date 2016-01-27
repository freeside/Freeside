% if ( $cgi->param('batch') ) {

  <% include( '/elements/header.html', ucfirst($type{$payby}). ' processing successful',
                 include('/elements/menubar.html'),

            )
  %>

  <% include( '/elements/small_custview.html', $cust_main, '', '', popurl(3). "view/cust_main.cgi" ) %>

  <% include('/elements/footer.html') %>

% #2.5/2.7?# } elsif ( $curuser->access_right('View payments') ) {
% } elsif ( $curuser->access_right(['View invoices', 'View payments']) ) {
<% $cgi->redirect(popurl(3). "view/cust_pay.html?paynum=$paynum" ) %>
% } else {
<% $cgi->redirect(popurl(3). "view/cust_main.html?custnum=$custnum" ) %>
% }
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied" unless $curuser->access_right('Process payment');

my $conf = new FS::Conf;

#some false laziness w/MyAccount::process_payment

$cgi->param('custnum') =~ /^(\d+)$/
  or die "illegal custnum ". $cgi->param('custnum');
my $custnum = $1;

my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
die "unknown custnum $custnum" unless $cust_main;

$cgi->param('amount') =~ /^\s*(\d*(\.\d\d)?)\s*$/
  or errorpage("illegal amount ". $cgi->param('amount'));
my $amount = $1;
errorpage("amount <= 0") unless $amount > 0;

if ( $cgi->param('fee') =~ /^\s*(\d*(\.\d\d)?)\s*$/ ) {
  my $fee = $1;
  $amount = sprintf('%.2f', $amount + $fee);
}

$cgi->param('year') =~ /^(\d+)$/
  or errorpage("illegal year ". $cgi->param('year'));
my $year = $1;

$cgi->param('month') =~ /^(\d+)$/
  or errorpage("illegal month ". $cgi->param('month'));
my $month = $1;

$cgi->param('payby') =~ /^(CARD|CHEK)$/
  or errorpage("illegal payby ". $cgi->param('payby'));
my $payby = $1;
my %payby2fields = (
  'CARD' => [ qw( address1 address2 city county state zip country ) ],
  'CHEK' => [ qw( ss paytype paystate stateid stateid_state ) ],
);
my %type = ( 'CARD' => 'credit card',
             'CHEK' => 'electronic check (ACH)',
           );

$cgi->param('payname') =~ /^([\w \,\.\-\']+)$/
  or errorpage(gettext('illegal_name'). " payname: ". $cgi->param('payname'));
my $payname = $1;

$cgi->param('payunique') =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
  or errorpage(gettext('illegal_text'). " payunique: ". $cgi->param('payunique'));
my $payunique = $1;

$cgi->param('balance') =~ /^\s*(\-?\s*\d*(\.\d\d)?)\s*$/
  or errorpage("illegal balance");
my $balance = $1;

my $payinfo;
my $paymask; # override only used by loaded cust payinfo, only implemented for realtime processing
my $paycvv = '';
my $loaded_cust_payby;
if ( $payby eq 'CHEK' ) {

  if ($cgi->param('payinfo1') =~ /xx/i || $cgi->param('payinfo2') =~ /xx/i ) {

    my $search_paymask = $cgi->param('payinfo1') . '@' . $cgi->param('payinfo2');
    $search_paymask .= '.' . $cgi->param('payinfo3')
      if $conf->config('echeck-country') eq 'CA';

    #paymask might not be saved in database, need to run paymask method for any potential match
    foreach my $search_cust_payby ($cust_main->cust_payby('CHEK','DCHK')) {
      if ($search_paymask eq $search_cust_payby->paymask) {
        # if there are multiple matches, assume for now that it's the first one returned,
        # since that's what auto-fills; it's unlikely a masked number would be entered by hand,
        # but it's very likely users will just click-through what's been auto-filled
        $loaded_cust_payby = $search_cust_payby;
        last;
      }
    }
    errorpage("Masked payinfo not found") unless $loaded_cust_payby;
    $payinfo = $loaded_cust_payby->payinfo;
    $paymask = $loaded_cust_payby->paymask;

  } else {
    $cgi->param('payinfo1') =~ /^(\d+)$/
      or errorpage("Illegal account number ". $cgi->param('payinfo1'));
    my $payinfo1 = $1;
    $cgi->param('payinfo2') =~ /^(\d+)$/
      or errorpage("Illegal ABA/routing number ". $cgi->param('payinfo2'));
    my $payinfo2 = $1;
    if ( $conf->config('echeck-country') eq 'CA' ) {
      $cgi->param('payinfo3') =~ /^(\d{5})$/
        or errorpage("Illegal branch number ". $cgi->param('payinfo2'));
      $payinfo2 = "$1.$payinfo2";
    }
    $payinfo = $payinfo1. '@'. $payinfo2;
  }

} elsif ( $payby eq 'CARD' ) {

  $payinfo = $cgi->param('payinfo');
  if ($payinfo =~ /xx/i) {

    #paymask might not be saved in database, need to run paymask method for any potential match
    foreach my $search_cust_payby ($cust_main->cust_payby('CARD','DCRD')) {
      if ($payinfo eq $search_cust_payby->paymask) {
        $loaded_cust_payby = $search_cust_payby;
        last;
      }
    }

    errorpage("Masked payinfo not found") unless $loaded_cust_payby;
    $payinfo = $loaded_cust_payby->payinfo;
    $paymask = $loaded_cust_payby->paymask;

  }

  $payinfo =~ s/\D//g;
  $payinfo =~ /^(\d{13,16}|\d{8,9})$/
    or errorpage(gettext('invalid_card'));
  $payinfo = $1;
  validate($payinfo)
    or errorpage(gettext('invalid_card'));

  unless ( $self->payinfo =~ /^99\d{14}$/ ) { #token

    my $cardtype = cardtype($payinfo);

    errorpage(gettext('unknown_card_type'))
      if $cardtype eq "Unknown";

    my %bop_card_types = map { $_=>1 } values %{ card_types() };
    errorpage("$cardtype not accepted") unless $bop_card_types{$cardtype};

  }

  if ( defined $cust_main->dbdef_table->column('paycvv') ) { #is this test necessary anymore?
    if ( length($cgi->param('paycvv') ) ) {
      if ( cardtype($payinfo) eq 'American Express card' ) {
        $cgi->param('paycvv') =~ /^(\d{4})$/
          or errorpage("CVV2 (CID) for American Express cards is four digits.");
        $paycvv = $1;
      } else {
        $cgi->param('paycvv') =~ /^(\d{3})$/
          or errorpage("CVV2 (CVC2/CID) is three digits.");
        $paycvv = $1;
      }
    }elsif( $conf->exists('backoffice-require_cvv') ){
      errorpage("CVV2 is required");
    }
  }

} else {
  die "unknown payby $payby";
}

$cgi->param('discount_term') =~ /^(\d*)$/
  or errorpage("illegal discount_term");
my $discount_term = $1;

# save first, for proper tokenization later
if ( $cgi->param('save') ) {

  my %saveopt;
  if ( $payby eq 'CARD' ) {
    my $bill_location = FS::cust_location->new;
    $bill_location->set( $_ => $cgi->param($_) )
      foreach @{$payby2fields{$payby}};
    $saveopt{'bill_location'} = $bill_location;
    $saveopt{'paycvv'} = $paycvv; # save_cust_payby contains conf logic for when to use this
    $saveopt{'paydate'} = "$year-$month-01";
  } else {
    # ss/stateid/stateid_state won't be saved, but should be harmless to pass
    %saveopt = map { $_ => scalar($cgi->param($_)) } @{$payby2fields{$payby}};
  }

  my $error = $cust_main->save_cust_payby(
    'payment_payby' => $payby,
    'auto'          => scalar($cgi->param('auto')),
    'payinfo'       => $payinfo,
    'paymask'       => $paymask,
    'payname'       => $payname,
    'paytype        => $paytype,
    %saveopt
  );

  errorpage("error saving info, payment not processed: $error")
    if $error;	
}

my $error = '';
my $paynum = '';
if ( $cgi->param('batch') ) {

  $error = 'Prepayment discounts not supported with batched payments' 
    if $discount_term;

  $error ||= $cust_main->batch_card(
                                     'payby'    => $payby,
                                     'amount'   => $amount,
                                     'payinfo'  => $payinfo,
                                     'paydate'  => "$year-$month-01",
                                     'payname'  => $payname,
                                     map { $_ => $cgi->param($_) } 
                                       @{$payby2fields{$payby}}
                                   );
  errorpage($error) if $error;

} else {

  $error = $cust_main->realtime_bop( $FS::payby::payby2bop{$payby}, $amount,
    'quiet'      => 1,
    'manual'     => 1,
    'balance'    => $balance,
    'payinfo'    => $payinfo,
    'paymask'    => $paymask,
    'paydate'    => "$year-$month-01",
    'payname'    => $payname,
    'payunique'  => $payunique,
    'paycvv'     => $paycvv,
    'paynum_ref' => \$paynum,
    'discount_term' => $discount_term,
    map { $_ => $cgi->param($_) } @{$payby2fields{$payby}}
  );
  errorpage($error) if $error;

  #no error, so order the fee package if applicable...
  if ( $cgi->param('fee_pkgpart') =~ /^(\d+)$/ ) {

    my $cust_pkg = new FS::cust_pkg { 'pkgpart' => $1 };

    my $error = $cust_main->order_pkg( 'cust_pkg' => $cust_pkg );
    errorpage("payment processed successfully, but error ordering fee: $error")
      if $error;

    #and generate an invoice for it now too
    $error = $cust_main->bill( 'pkg_list' => [ $cust_pkg ] );
    errorpage("payment processed and fee ordered sucessfully, but error billing fee: $error")
      if $error;

  }

  $cust_main->apply_payments;

}

#success!

</%init>
