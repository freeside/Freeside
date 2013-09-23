<? $title ='Webpay Payment'; include('elements/header.php'); ?>
<? $current_menu = 'payment_webpay.php'; include('elements/menu.php'); ?>
<?
if ( isset($_POST['amount']) && $_POST['amount'] ) {

  $payment_results = $freeside->start_thirdparty(array(
    'session_id'  => $_COOKIE['session_id'],
    'method'      => 'CC',
    'amount'      => $_POST['amount'],
  ));

  include('elements/post_thirdparty.php');

} else {

  $payment_info = $freeside->payment_info( array(
    'session_id' => $_COOKIE['session_id'],
  ) );

  $tr_amount_fee = $freeside->mason_comp(array(
    'session_id'  => $_COOKIE['session_id'],
    'comp'        => '/elements/tr-amount_fee.html',
    'args'        => [ 'amount', $payment_info['balance'] ],
  ));
  $tr_amount_fee = $tr_amount_fee['output'];

  include('elements/error.php'); ?>
<FORM NAME="OneTrueForm" METHOD="POST" ACTION="payment_webpay.php">
  <TABLE>
  <TR>
    <TD ALIGN="right">Amount&nbsp;Due</TD>
    <TD>$<? echo sprintf('%.2f', $payment_info['balance']); ?></TD>
  </TR>
  <? echo $tr_amount_fee; ?>
  </TABLE>
  <BR>
  <INPUT TYPE="submit" NAME="process" VALUE="Start payment">
</FORM>
<? } ?>
<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
