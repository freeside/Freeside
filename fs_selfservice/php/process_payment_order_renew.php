<?php

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->process_payment_order_renew( array( 
    'session_id' => $_POST['session_id'],
    'payby'      => 'CARD',
    'amount'     => $_POST['amount'],
    'payinfo'    => $_POST['payinfo'],
    'paycvv'     => $_POST['paycvv'],
    'month'      => $_POST['month'],
    'year'       => $_POST['year'],
    'payname'    => $_POST['payname'],
    'address1'   => $_POST['address1'],
    'address2'   => $_POST['address2'],
    'city'       => $_POST['city'],
    'state'      => $_POST['state'],
    'zip'        => $_POST['zip'],
    'save'       => $_POST['save'],
    'auto'       => $_POST['auto'],
    'paybatch'   => $_POST['paybatch'],
) );

error_log("[process_payment_order_renew] received response from freeside: $response");

$error = $response['error'];

if ( $error ) {

  error_log("[process_payment_order_renew] response error: $error");

  header('Location:order_renew.php'.
           '?session_id='. urlencode($_POST['session_id']).
           '?error='.      urlencode($error).
           '&payby=CARD'.
           '&amount='.     urlencode($_POST['amount']).
           '&payinfo='.    urlencode($_POST['payinfo']).
           '&paycvv='.     urlencode($_POST['paycvv']).
           '&month='.      urlencode($_POST['month']).
           '&year='.       urlencode($_POST['year']).
           '&payname='.    urlencode($_POST['payname']).
           '&address1='.   urlencode($_POST['address1']).
           '&address2='.   urlencode($_POST['address2']).
           '&city='.       urlencode($_POST['city']).
           '&state='.      urlencode($_POST['state']).
           '&zip='.        urlencode($_POST['zip']).
           '&save='.       urlencode($_POST['save']).
           '&auto='.       urlencode($_POST['auto']).
           '&paybatch='.   urlencode($_POST['paybatch'])
        );
  die();

}

// sucessful renewal.

$session_id = $response['session_id'];

// now what?

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
  <HEAD>
    <TITLE>Renew Early</TITLE>
  </HEAD>
  <BODY>
    <H1>Renew Early</H1>

    Renewal processed sucessfully.

  </BODY>
</HTML>
