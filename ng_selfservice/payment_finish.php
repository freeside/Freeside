<? $title ='Payment Confirmation'; include('elements/header.php'); ?>
<? $current_menu = ''; include('elements/menu.php'); ?>
<?
  $params = $_GET;
  $params['session_id'] = $_COOKIE['session_id'];

  //print_r($params);
  $payment_results = $freeside->finish_thirdparty($params);

  if ( isset($payment_results['error']) ) {
    $error = $payment_results['error'];
    include('elements/error.php');
  } else {
?>
<TABLE>
  <TR>
    <TH COLSPAN=2><FONT SIZE=+1><B>Your payment details</B></FONT></TH>
  </TR>
  <TR>
<TR>
  <TD ALIGN="right">Payment&nbsp;#</TD>
  <TD BGCOLOR="#ffffff"><B><? echo($payment_results['paynum']); ?></B></TD>
</TR>
<TR>
  <TD ALIGN="right">Payment&nbsp;amount</TH>
  <TD BGCOLOR="#ffffff"><B>$<? printf('%.2f', $payment_results['paid']); ?></B>
  </TD>
</TR>
<TR>
  <TD ALIGN="right">Processing&nbsp;#</TD>
  <TD BGCOLOR="#ffffff"><B><? echo($payment_results['order_number']); ?></B>
  </TD>
</TR>
<? } ?>
