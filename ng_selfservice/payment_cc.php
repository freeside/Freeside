<? $title ='Credit Card Payment'; include('elements/header.php'); ?>
<? $current_menu = 'payment_cc.php'; include('elements/menu.php'); ?>
<?

if ( isset($_POST['amount']) && $_POST['amount'] ) {

  $payment_results = $freeside->process_payment(array(
    'session_id' => $_COOKIE['session_id'],
    'payby'      => 'CARD',
    'amount'     => $_POST['amount'],
    'payinfo'    => $_POST['payinfo'],
    'paycvv'     => $_POST['paycvv'],
    'month'      => $_POST['month'],
    'year'       => $_POST['year'],
    'payname'    => $_POST['payname'],
    'address1'   => $_POST['address1'],
    'address2'   => $_POST['address2'],
    'city'       => $_POST['city'],
    'state'      => $_POST['state'],
    'zip'        => $_POST['zip'],
    'country'    => $_POST['country'],
    'save'       => $_POST['save'],
    'auto'       => $_POST['auto'],
    'paybatch'   => $_POST['paybatch'],
    //'discount_term' => $discount_term,
  ));

  if ( $payment_results['error'] ) {
    $payment_error = $payment_results['error'];
  } else {
    $receipt_html = $payment_results['receipt_html'];
  }

}

if ( $receipt_html ) { ?>

  Your payment was processed successfully.  Thank you.<BR><BR>
  <? echo $receipt_html; ?>

<? } else {

  $payment_info = $freeside->payment_info( array(
    'session_id' => $_COOKIE['session_id'],
  ) );

  if ( isset($payment_info['error']) && $payment_info['error'] ) {
    $error = $payment_info['error'];
    header('Location:index.php?error='. urlencode($error));
    die();
  }

  extract($payment_info);

  $error = $payment_error;

  $tr_amount_fee = $freeside->mason_comp(array(
      'session_id' => $_COOKIE['session_id'],
      'comp'       => '/elements/tr-amount_fee.html',
      'args'       => [ 'amount',  $balance ],
  ));
  //$tr_amount_fee = $tr_amount_fee->{'error'} || $tr_amount_fee->{'output'};
  $tr_amount_fee = $tr_amount_fee['output'];

  ?>

  <? include('elements/error.php'); ?>

  <FORM NAME="OneTrueForm" METHOD="POST" ACTION="payment_cc.php" onSubmit="document.OneTrueForm.process.disabled=true">

  <TABLE>
  <TR>
    <TD ALIGN="right">Amount&nbsp;Due</TD>
    <TD COLSPAN=7>
      <TABLE><TR><TD>
        $<? echo sprintf("%.2f", $balance) ?>
      </TD></TR></TABLE>
    </TD>
  </TR>

  <? echo $tr_amount_fee; ?>

  <? //include('elements/discount_term.php') ?>

  <TR>
    <TD ALIGN="right">Card&nbsp;type</TD>
    <TD COLSPAN=7>
      <SELECT NAME="card_type"><OPTION></OPTION>
        <? foreach ( $card_types AS $ct ) { ?>
          <OPTION <? if ( $card_type == $card_types[$ct] ) { echo 'SELECTED'; } ?>
                  VALUE="<? echo $card_types[$ct]; ?>"><? echo $ct; ?>
        <? } ?>
      </SELECT>
    </TD>
  </TR>

  <? include('elements/card.php'); ?>

  <TR>
    <TD COLSPAN=8>
      <INPUT TYPE="checkbox" <? if ( ! $save_unchecked ) { echo 'CHECKED'; } ?> NAME="save" VALUE="1">
      Remember this card and billing address
    </TD>
  </TR><TR>
    <TD COLSPAN=8>
      <INPUT TYPE="checkbox" <? if ( $payby == 'CARD' ) { echo ' CHECKED'; } ?> NAME="auto" VALUE="1" onClick="if (this.checked) { document.OneTrueForm.save.checked=true; }">
      Charge future payments to this card automatically
    </TD>
  </TR>
  </TABLE>
  <BR>
  <INPUT TYPE="hidden" NAME="paybatch" VALUE="<? echo $paybatch ?>">
  <INPUT TYPE="submit" NAME="process" VALUE="Process payment"> <!-- onClick="this.disabled=true"> -->
  </FORM>

<? } ?>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
