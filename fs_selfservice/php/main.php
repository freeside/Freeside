<?php

require('freeside.class.php');
$freeside = new FreesideSelfService();

$session_id = $_GET['session_id'];

$response = $freeside->customer_info( array(
  'session_id' => $session_id,
) );

$error = $response['error'];

if ( $error ) {
  header('Location:login.php?error='. urlencode($error));
  die();
}

extract($response);

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
  <HEAD>
    <TITLE>My Account</TITLE>
  </HEAD>
  <BODY>
    <H1>My Account</H1>

      Hello, <?php echo htmlspecialchars($name); ?><BR><BR>

      <?php echo $small_custview; ?>

      <BR>

      <A HREF="order_renew.php?session_id=<?php echo $session_id; ?>">Renew early</A>

  </BODY>
</HTML>
