<? $title ='Make A Payment'; include('elements/header.php'); ?>
<? $current_menu = 'payment_only_payment.php'; include('elements/payment_only_menu.php'); ?>

<?

if ( isset($_POST['amount']) && $_POST['amount'] ) {

  $payment_results = $freeside->payment_only_process_payment(array(
    'session_id' => $_COOKIE['session_id'],
    'payby'      => $_POST['payby'],
    'amount'     => $_POST['amount'],
    'paybatch'   => $_POST['paybatch'],
    //'discount_term' => $discount_term,
  ));

  if ( $payment_results['error'] ) {
    $error = $payment_results['error'];
  } else {
    $receipt_html = $payment_results['receipt_html'];
  }

}

#echo print_r($payment_results);

if ( $receipt_html ) { 
?>

  Your payment was processed successfully.  Thank you.<BR><BR>
  <? echo $receipt_html; ?>

<? } else {

  $payment_info = $freeside->payment_only_payment_info( array(
    'session_id' => $_COOKIE['session_id'],
  ) );

  if ( isset($payment_info['error']) && $payment_info['error'] ) {
    $error = $payment_info['error'];
    // possible to just keep on this page
    header('Location:payment_only_error.php?error='. urlencode($error));
    die();
  }

  extract($payment_info);

  $tr_amount_fee = $freeside->payment_only_mason_comp(array(
      'session_id' => $_COOKIE['session_id'],
      'comp'       => '/elements/tr-amount_fee.html',
      'args'       => [ 'amount',  $balance ],
  ));
  //$tr_amount_fee = $tr_amount_fee->{'error'} || $tr_amount_fee->{'output'};
  $tr_amount_fee = $tr_amount_fee['output'];

 ?>

  <? include('elements/error.php'); ?>

  <SCRIPT TYPE="text/javascript">

      function payby_changed(what) {
        var amount = document.getElementById('amount');
        var amountdue = document.getElementById('amountdue');
        var surcharge_cell = document.getElementById('ajax_surcharge_cell');
        var surcharge_percentage = document.getElementById('surcharge_percentage');
        var surcharge_flatfee = document.getElementById('surcharge_flatfee');
        if (what.value == "CHEK") {
          surcharge_cell.style.display = 'none';
          amount.value = amountdue.value;

        }
        else if (what.value == "CARD") {
        	surcharge_cell.style.display = 'inline';
        	amount.value = (+amountdue.value + (+amountdue.value * +surcharge_percentage.value) + +surcharge_flatfee.value).toFixed(2);
        }
      }

    </SCRIPT>

  <FORM NAME="OneTrueForm" METHOD="POST" ACTION="payment_only_payment.php" onSubmit="document.OneTrueForm.process.disabled=true">

  <TABLE>

  <TR>
  	<TD ALIGN="right"><B>Payment account</B></TD>
  	<TD COLSPAN=7>
  	  <SELECT ID="payby" NAME="payby" onChange="payby_changed(this)">
<? if ($CARD) { ?>
         <OPTION VALUE="CARD"><? echo $card_type ?> <? echo $card_mask ?></OPTION>
<? } ?>
<? if ($CHEK) { ?>
         <OPTION VALUE="CHEK"><? echo $check_type ?> <? echo $check_mask ?></OPTION>
<? } ?> 	  	
  	  </SELECT>
  	</TD>
  </TR>
  	
  <TR>
    <TD ALIGN="right"><B>Amount&nbsp;Due</B></TD>
    <TD COLSPAN=7>
      <TABLE><TR><TD>
        $<? echo sprintf("%.2f", $balance) ?>
        <INPUT TYPE=hidden NAME="amountdue" ID="amountdue" VALUE="<? echo sprintf("%.2f", $balance) ?>" >
      </TD></TR></TABLE>
    </TD>
  </TR>

  <? echo $tr_amount_fee; ?>

  </TABLE>
  <BR>
  <INPUT TYPE="hidden" NAME="paybatch" VALUE="<? echo $paybatch ?>">
  <INPUT TYPE="submit" NAME="process" VALUE="Process payment"> <!-- onClick="this.disabled=true"> -->
  </FORM>

<? } ?>
<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>