<? $title ='Payment Accounts'; include('elements/header.php'); ?>
<? $current_menu = 'payment_accounts.php'; include('elements/menu.php'); ?>
<H1>My Payment Accounts</H1>
<br>

<?
if ( isset($_GET['action']) && $_GET['action'] ) {
  $action = $_GET['action'];
}

if ($action == 'deleteaccount') {

    if ( isset($_GET['paybynum']) && $_GET['paybynum'] ) {
      if ( preg_match( '/^(\d+)$/', $_GET['paybynum'] ) ) {
        $paybynum = $_GET['paybynum'];
        $error = $freeside->delete_payby( array(
          'session_id' => $_COOKIE['session_id'],
          'custpaybynum' => $paybynum,
        ) );
      }
      else {
        $error['error'] = 'Bad Payby Number';
      }
    }

  if ( isset($error['error']) && $error['error'] ) {
    $error = $error['error'];
  }
  else {
    $error = "Account " . $paybynum . " Deleted";
  }

?>
   <FONT COLOR="red"><? echo $error ?></FONT>
   <P>
<?
}

  $payment_info = $freeside->list_payby( array(
    'session_id' => $_COOKIE['session_id'],
  ) );

  if ( isset($payment_info['error']) && $payment_info['error'] ) {
    $error = $payment_info['error'];
    header('Location:index.php?error='. urlencode($error));
    die();
  }

  extract($payment_info);
?>

<TABLE>
 <TR>
   <TD>&nbsp;</TD>
   <TD>Type</TD>
   <TD>Account Type</TD>
   <TD>Account Mask</TD>
   <TD>Bank Name</TD>
 </TR>

<?
  foreach ($payby as $payaccount) {
?>
    <TR>
      <TD><A HREF="payment_accounts.php?action=deleteaccount&paybynum=<? echo $payaccount['custpaybynum'] ?>">delete</A></TD>
      <TD><? echo $payaccount['payby'] ?></TD>
      <TD><? echo $payaccount['paytype'] ?></TD>
      <TD><? echo $payaccount['paymask'] ?></TD>
      <TD><? echo htmlspecialchars($payaccount['payname']) ?></TD>
     </TR>
 <?
  }
 ?>

</TABLE>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
