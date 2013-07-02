<? $title ='Electronic Check Payment'; include('elements/header.php'); ?>
<? $current_menu = 'payment_ach.php'; include('elements/menu.php'); ?>
<?

if ( isset($_POST['amount']) && $_POST['amount'] ) {

  $payment_results = $freeside->process_payment(array(
    'session_id'    => $_COOKIE['session_id'],
    'payby'         => 'CHEK',
    'amount'        => $_POST['amount'],
    'payinfo1'      => $_POST['payinfo1'],
    'payinfo2'      => $_POST['payinfo2'],
    'month'         => 12,
    'year'          => 2037,
    'payname'       => $_POST['payname'],
    'paytype'       => $_POST['paytype'],
    'paystate'      => $_POST['paystate'],
    'ss'            => $_POST['ss'],
    'stateid'       => $_POST['stateid'],
    'stateid_state' => $_POST['stateid_state'],
    'save'          => $_POST['save'],
    'auto'          => $_POST['auto'],
    'paybatch'      => $_POST['paybatch'],
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

  ?>

  <? include('elements/error.php'); ?>

  <FORM NAME="OneTrueForm" METHOD="POST" ACTION="payment_ach.php" onSubmit="document.OneTrueForm.process.disabled=true">

  <TABLE>
  <TR>
    <TD ALIGN="right">Amount&nbsp;Due</TD>
    <TD>
      <TABLE><TR><TD BGCOLOR="#ffffff">
        $<? echo sprintf("%.2f", $balance) ?>
      </TD></TR></TABLE>
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right">Payment&nbsp;amount</TD>
    <TD>
      <TABLE><TR><TD BGCOLOR="#ffffff">
        $<INPUT TYPE="text" NAME="amount" SIZE=8 VALUE="<? echo sprintf("%.2f", $balance) ?>">
      </TD></TR></TABLE>
    </TD>
  </TR>
  <? // include('elements/discount_term.php') ?>

  <? include('elements/check.php') ?>

  <TR>
    <TD COLSPAN=2>
      <INPUT TYPE="checkbox" <? if ( ! $save_unchecked ) { echo 'CHECKED'; } ?> NAME="save" VALUE="1">
      Remember this information
    </TD>
  </TR><TR>
    <TD COLSPAN=2>
      <INPUT TYPE="checkbox" <? if ( $payby == 'CARD' ) { echo ' CHECKED'; } ?> NAME="auto" VALUE="1" onClick="if (this.checked) { document.OneTrueForm.save.checked=true; }">
      Charge future payments to this account automatically
    </TD>
  </TR>
  </TABLE>
  <BR>
  <INPUT TYPE="hidden" NAME="paybatch" VALUE="<? echo $paybatch; ?>">
  <INPUT TYPE="submit" NAME="process" VALUE="Process payment"> <!-- onClick="this.disabled=true"> -->
  </FORM>

<? } ?>
  
<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
