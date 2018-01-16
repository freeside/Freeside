<? $title ='Make A Payment'; include('elements/header.php'); ?>
<? $current_menu = 'payment.php'; include('elements/menu.php'); ?>

<?
$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['session_id'],
) );


if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($customer_info);

?>

<? include('elements/error.php'); ?>

<P>Hello <? echo htmlspecialchars($name); ?></P>

<P>Your current balance is <B>$<? echo $balance ?></B> how would you like to make a payment today?</P>

<div STYLE="margin-left: 25px;">
<a href="payment_cc.php">Credit card payment</A><BR><BR>
<a href="payment_ach.php">Electronic check payment</A><BR><BR>
<a href="payment_paypal.php">PayPal payment</A><BR><BR>
<a href="payment_webpay.php">Webpay payment</A><BR><BR>
</div>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>