%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "cust_refund.cgi?". $cgi->query_string ) %>
%} else {
%
%  if ( $link eq 'popup' ) {
%
<& /elements/header-popup.html, 'Refund entered' &>
    <SCRIPT TYPE="text/javascript">
      topreload();
    </SCRIPT>

    </BODY></HTML>
%  } else {
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?custnum=$custnum;show=payment_history") %>
%  }
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Refund payment')
      || $FS::CurrentUser::CurrentUser->access_right('Post refund');

my $conf = new FS::Conf;

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
my $custnum = $1;
my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
  or die "unknown custnum $custnum";

my $link    = $cgi->param('popup') ? 'popup' : '';

my $payby = $cgi->param('payby');

die "access denied"
  unless $FS::CurrentUser::CurrentUser->refund_access_right($payby);

$cgi->param('reasonnum') =~ /^(-?\d+)$/ or die "Illegal reasonnum";
my ($reasonnum, $error) = $m->comp('/misc/process/elements/reason');
$cgi->param('reasonnum', $reasonnum) unless $error;

if ( $error ) {
  # do nothing
} elsif ( $payby =~ /^(CARD|CHEK)$/ ) { 
  my %options = ();
  my $bop = $FS::payby::payby2bop{$1};

  my %payby2fields = (
  'CARD' => [ qw( address1 address2 city county state zip country ) ],
  'CHEK' => [ qw( ss paytype paystate stateid stateid_state ) ],
  );
  my %type = ( 'CARD' => 'credit card',
             'CHEK' => 'electronic check (ACH)',
             );

my( $cust_payby, $payinfo, $paycvv, $month, $year, $payname );
my $paymask = '';
if ( (my $custpaybynum = scalar($cgi->param('custpaybynum'))) > 0 ) {

  ##
  # use stored cust_payby info
  ##

  $cust_payby = qsearchs('cust_payby', { custnum      => $custnum,
                                            custpaybynum => $custpaybynum, } )
    or die "unknown custpaybynum $custpaybynum";

  # not needed for realtime_bop, but still needed for batch_card
  $payinfo = $cust_payby->payinfo;
  $paymask = $cust_payby->paymask;
  $paycvv = $cust_payby->paycvv; # pass it if we got it, running a transaction will clear it
  ( $month, $year ) = $cust_payby->paydate_mon_year;
  $payname = $cust_payby->payname;

} else {

  ##
  # use new info
  ##

  $cgi->param('year') =~ /^(\d+)$/
    or errorpage("illegal year ". $cgi->param('year'));
  $year = $1;

  $cgi->param('month') =~ /^(\d+)$/
    or errorpage("illegal month ". $cgi->param('month'));
  $month = $1;

  $cgi->param('payname') =~ /^([\w \,\.\-\']+)$/
    or errorpage(gettext('illegal_name'). " payname: ". $cgi->param('payname'));
  $payname = $1;

  if ( $payby eq 'CHEK' ) {

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
    $payinfo = $payinfo1 . '@'. $payinfo2;

  } elsif ( $payby eq 'CARD' ) {

    $payinfo = $cgi->param('payinfo');

    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,19}|\d{8,9})$/
      or errorpage(gettext('invalid_card'));
    $payinfo = $1;
    validate($payinfo)
      or errorpage(gettext('invalid_card'));

    unless ( $cust_main->tokenized($payinfo) ) { #token

      my $cardtype = cardtype($payinfo);

      errorpage(gettext('unknown_card_type'))
        if $cardtype eq "Unknown";

      my %bop_card_types = map { $_=>1 } values %{ card_types() };
      errorpage("$cardtype not accepted") unless $bop_card_types{$cardtype};

    }

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
    } elsif ( $conf->exists('backoffice-require_cvv') ){
      errorpage("CVV2 is required");
    }

  } else {
    die "unknown payby $payby";
  }

  # save first, for proper tokenization
  if ( $cgi->param('save') ) {

    my %saveopt;
    if ( $payby eq 'CARD' ) {
      my $bill_location = FS::cust_location->new;
      $bill_location->set( $_ => scalar($cgi->param($_)) )
        foreach @{$payby2fields{$payby}};
      $saveopt{'bill_location'} = $bill_location;
      $saveopt{'paycvv'} = $paycvv; # save_cust_payby contains conf logic for when to use this
      $saveopt{'paydate'} = "$year-$month-01";
    } else {
      # ss/stateid/stateid_state won't be saved, but should be harmless to pass
      %saveopt = map { $_ => scalar($cgi->param($_)) } @{$payby2fields{$payby}};
    }

    my $error = $cust_main->save_cust_payby(
      'saved_cust_payby' => \$cust_payby,
      'payment_payby' => $payby,
      'auto'          => scalar($cgi->param('auto')),
      'weight'        => scalar($cgi->param('weight')),
      'payinfo'       => $payinfo,
      'payname'       => $payname,
      %saveopt
    );

    errorpage("error saving info, payment not processed: $error")
      if $error;

  } elsif ( $payby eq 'CARD' ) { # not saving

    $paymask = FS::payinfo_Mixin->mask_payinfo('CARD',$payinfo); # for untokenized but tokenizable payinfo

  }

}

##
# now run the refund
##

  $cgi->param('refund') =~ /^(\d*)(\.\d{2})?$/
    or die "illegal refund amount ". $cgi->param('refund');
  my $refund = "$1$2";
  $cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
  my $paynum = $1;
  my $paydate = $cgi->param('exp_year'). '-'. $cgi->param('exp_month'). '-01';
  $options{'paydate'} = $paydate if $paydate =~ /^\d{2,4}-\d{1,2}-01$/;

  if ( $cgi->param('batch') ) {

    $error ||= $cust_main->batch_card(
                                     'payby'    => $payby,
                                     'amount'   => $refund,
                                     'payinfo'  => $payinfo,
                                     'paydate'  => "$year-$month-01",
                                     'payname'  => $payname,
                                     'paycode'  => 'C',
                                     map { $_ => scalar($cgi->param($_)) }
                                       @{$payby2fields{$payby}}
                                   );
    errorpage($error) if $error;

#### post refund #####
    my %hash = map {
      $_, scalar($cgi->param($_))
    } fields('cust_refund');
    $paynum = $cgi->param('paynum');
    $paynum =~ /^(\d*)$/ or die "Illegal paynum!";
    if ($paynum) {
      my $cust_pay = qsearchs('cust_pay',{ 'paynum' => $paynum });
      die "Could not find paynum $paynum" unless $cust_pay;
      $error = $cust_pay->refund(\%hash);
    } else {
      my $new = new FS::cust_refund ( \%hash );
      $error = $new->insert;
    }
    # if not a batch refund run realtime.
  } else {
    $error = $cust_main->realtime_refund_bop( $bop, 'amount' => $refund,
                                                  'paynum' => $paynum,
                                                  'reasonnum' => scalar($cgi->param('reasonnum')),
                                                  %options );
  }
} else {
  my %hash = map {
    $_, scalar($cgi->param($_))
  } fields('cust_refund');
  my $paynum = $cgi->param('paynum');
  $paynum =~ /^(\d*)$/ or die "Illegal paynum!";
  if ($paynum) {
    my $cust_pay = qsearchs('cust_pay',{ 'paynum' => $paynum });
    die "Could not find paynum $paynum" unless $cust_pay;
    $error = $cust_pay->refund(\%hash);
  } else {
    my $new = new FS::cust_refund ( \%hash );
    $error = $new->insert;
  }
}

</%init>
