<?php

$GLOBALS['FREESIDE_PROCESS_LOGIN'] = true;
//error_log($GLOBALS['$FREESIDE_PROCESS_LOGIN']);

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

//add_action('muplugins_loaded', 'freeside_process_login');
//error_log("action added");

function notfreeside_process_login() {
error_log("FINALLY action run");

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

  wp_redirect('example_login.php?username='. urlencode($username).
                           '&domain='.   urlencode($domain).
                           '&email='.    urlencode($email).
                           '&freeside_error='.    urlencode($error)
        );
  exit;

}

// sucessful login

$session_id = $response['session_id'];

error_log("[login] logged into freeside with session_id=$session_id, setting cookie");

// now what?  for now, always redirect to the main page (or the select a
// customer diversion).
// eventually, other options?

setcookie('session_id', $session_id);

}

$response = $GLOBALS['FREESIDE_LOGIN_RESPONSE'];

if ( $response['custnum'] || $response['svcnum'] ) {

  error_log('redirecting to example_selfservice.php');
  wp_redirect("example_selfservice.php");
  exit;

} elseif ( $response['customers'] ) {
  error_log('sending header');
  get_header();
?>

  <?php include('elements/error.php'); ?>

  <FORM NAME="SelectCustomerForm" ACTION="process_select_cust.php" METHOD=POST>
  <INPUT TYPE="hidden" NAME="action" VALUE="switch_cust">

  <TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>

    <TR>
      <TH ALIGN="right">Customer </TH>
      <TD>
        <SELECT NAME="custnum" ID="custnum" onChange="custnum_changed()">
          <OPTION VALUE="">Select a customer
          <?php foreach ( $response['customers'] AS $custnum => $customer ) { ?>
            <OPTION VALUE="<?php echo $custnum ?>"><?php echo htmlspecialchars( $customer ) ?>
          <?php } ?>
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

<?php

// } else {
// 
//   die 'login successful, but unrecognized info (no custnum, svcnum or customers)';
  
}

?>

<?php get_footer(); ?>

