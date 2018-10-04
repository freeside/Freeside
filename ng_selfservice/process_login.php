<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->login( array( 
  'email'    => strtolower($_POST['email']),
  'username' => strtolower($_POST['username']),
  'domain'   => strtolower($_POST['domain']),
  'password' => $_POST['password'],
) );

#error_log("[login] received response from freeside: $response");

$error = $response['error'];

if ( $error ) {

  header('Location:index.php?username='. urlencode($username).
                           '&domain='.   urlencode($domain).
                           '&email='.    urlencode($email).
                           '&error='.    urlencode($error)
        );
  die();

}

// sucessful login

$session_id = $response['session_id'];

error_log("[login] logged into freeside with session_id=$session_id, setting cookie");

// now what?  for now, always redirect to the main page (or the select a
// customer diversion).
// eventually, other options?

setcookie('session_id', $session_id);

if ( $response['custnum'] || $response['svcnum'] ) {

  header("Location:main.php");
  die();

} elseif ( $response['customers'] ) {
var_dump($response['customers']);
?>

  <? $title ='Select customer'; include('elements/header.php'); ?>
  <? include('elements/error.php'); ?>

  <FORM NAME="SelectCustomerForm" ACTION="process_select_cust.php" METHOD=POST>
  <INPUT TYPE="hidden" NAME="action" VALUE="switch_cust">

  <TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>

    <TR>
      <TH ALIGN="right">Customer </TH>
      <TD>
        <SELECT NAME="custnum" ID="custnum" onChange="custnum_changed()">
          <OPTION VALUE="">Select a customer
          <? foreach ( $response['customers'] AS $custnum => $customer ) { ?>
            <OPTION VALUE="<? echo $custnum ?>"><? echo htmlspecialchars( $customer ) ?>
          <? } ?>
        </SELECT>
      </TD>
    </TR>

    <TR>
      <TD COLSPAN=2 ALIGN="center"><INPUT TYPE="submit" ID="submit" VALUE="Select customer" DISABLED></TD>
    </TR>

  </TABLE>
  </FORM>

  <SCRIPT TYPE="text/javascript">

  function custnum_changed () {
    var form = document.SelectCustomerForm;
    if ( form.custnum.selectedIndex > 0 ) {
      form.submit.disabled = false;
    } else {
      form.submit.disabled = true;
    }
  }

  </SCRIPT>

  <? include('elements/footer.php'); ?>

<?

// } else {
// 
//   die 'login successful, but unrecognized info (no custnum, svcnum or customers)';
  
}

?>
