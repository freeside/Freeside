<?php

$GLOBALS['FREESIDE_PROCESS_LOGIN'] = true;

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

$response = $GLOBALS['FREESIDE_LOGIN_RESPONSE'];

if ( $response['custnum'] || $response['svcnum'] ) {

  wp_redirect("example_selfservice.php");
  exit;

} elseif ( $response['customers'] ) {
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

