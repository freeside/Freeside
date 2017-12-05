<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );
get_header();

$freeside = new FreesideSelfService();

if ( isset($_POST['email']) ) {

  $result = $freeside->reset_passwd(array(
    'email' => $_POST['email'],
  ));

  if ( $result['error'] ) {
    $_REQUEST['freeside_error'] = $result['error'];
  } else {
    $sent = 1;
  }

}

?>

<?php if ( $sent == 1 ) { ?>

        A verification email has been sent to your mailbox.  Please follow the
        link in your email to complete your password reset.

<?php } else { ?>

Please enter your email address.  A password reset email will be sent to that
address<BR><BR>

<?php include('elements/error.php'); ?>

<FORM METHOD="POST">
<INPUT TYPE="text" NAME="email" VALUE=""><BR>
<INPUT TYPE="submit" VALUE="Send reset email">
</FORM>

<?php } ?>

<?php get_footer(); ?>
