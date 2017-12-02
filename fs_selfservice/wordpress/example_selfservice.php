<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

$freeside = new FreesideSelfService();

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

?>

<h3>Billing</h3>

<p><big><strong>Name</strong></big></p>
<p><?php echo htmlspecialchars($name); ?></p>

<?php if ( $signupdate_pretty ) { ?>
  <p><big><strong>Signup Date</strong></big></p>
  <p><?php echo htmlspecialchars($signupdate_pretty); ?></p>
<?php } ?>

<p><big><strong>Username</strong></big></p>
<p><?php echo htmlspecialchars($svc_label) ?></p>

<p><big><strong>Account Number</strong></big></p>
<p><?php echo $display_custnum ?></p>

<p><big><strong>Address</strong></big></p>
<address>
<?php echo htmlspecialchars($address1); ?><br>
<?php echo strlen($address2) ? htmlspecialchars($address2).'<br>' : '' ?>
<?php echo $city ?>, <?php echo $state ?>  <?php echo $zip ?><br>
<?php echo $country ?>
</address>

<p><big><strong>Email Address</strong></big></p>
<p><?php echo htmlspecialchars($invoicing_list) ?></p>

<br>
<br>
<br>
<p><big><strong>Total Balance</strong></big></p>
<h4><?php echo $balance_pretty ?></h4>

<br>
<br>
<br>
<p><a href="view_invoice.php?invnum=<?php echo $max_invnum ?>">View my Bill</a></p>
<p><a href="change_bill.php">Change Bill Deliver Options</a></p>
<p><a href="services_new.php">Order a new service</a></p>
<p><a href="payment_cc.php">Credit card payment</a></p>
<p><a href="process_logout.php">Logout</a></p>


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
