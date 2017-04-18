<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

$freeside = new FreesideSelfService();

error_log( "COOKIE: ". $_COOKIE['freeside_session_id'] );
error_log( "COOKIE: ". $GLOBALS['FREESIDE_SESSION_ID'] );

$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['freeside_session_id'],
) );


if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
  wp_redirect('example_login.php?freeside_error='. urlencode($error));
  die();
}

extract($customer_info);

get_header();

error_log( "COOKIE: ". $_COOKIE['freeside_session_id'] );

?>

<P>Hello <?php echo htmlspecialchars($name); ?></P>

<?php if ( $signupdate_pretty ) { ?>
  <P>Thank you for being a customer since <?php echo $signupdate_pretty; ?></P>
<?php } ?>

<P>Your account number is: <B><?php echo $display_custnum ?></B></P>

<P>Your current balance is: <B><?php echo $balance_pretty ?></B></P>

<?php echo $announcement ?>

<!--
your open invoices if you have any & payment link if you have one.  more insistant if you're late?
<BR><BR>

your tickets.  some notification if there's new responses since your last login 
<BR><BR>

anything else?
-->

<?php get_footer(); ?>
