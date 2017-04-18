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

<h3>Billing</h3>

<p><big><strong>Name</strong></big></p>
<p><?php echo htmlspecialchars($name); ?></p>

<?php if ( $signupdate_pretty ) { ?>
  <p><big><strong>Signup Date</strong></big></p>
  <p><?php echo htmlspecialchars($signupdate_pretty); ?></p>
<?php } ?>

<p><big><strong>Username</strong></big></p>
<p>me@gmail.com</p>

<p><big><strong>Account Number</strong></big></p>
<p><?php echo $display_custnum ?></p>

<p><big><strong>Address</strong></big></p>
<address>
Box 564, Disneyland<br>
USA
</address>

<p><big><strong>Email Address</strong></big></p>
<p>me@gmail.com</p>

<br>
<br>
<br>
<p><big><strong>Total Balance</strong></big></p>
<h4><?php echo $balance_pretty ?></h4>

<br>
<br>
<br>
<p><big><strong> <font color="	#4682B4">View my Bill</strong></big></font></p>
<p><big><strong> <font color="#4682B4">Change Bill Deliver Options</strong></big></font></p>



<h3>Services</h3>

<h4><font color="#4682B4"> <i class="fa fa-laptop"> </i> </font> Internet </h4>
<h4><font color="#4682B4"> <i class="fa fa-volume-control-phone"> </i> </font>   Voice </h4>


<?php echo $announcement ?>

<!--
your open invoices if you have any & payment link if you have one.  more insistant if you're late?
<BR><BR>

your tickets.  some notification if there's new responses since your last login 
<BR><BR>

anything else?
-->


<?php get_footer(); ?>
