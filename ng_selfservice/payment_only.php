<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$ip = $_SERVER['REMOTE_ADDR'];

$mac = $freeside->get_mac_address( array('ip' => $ip, ) );

$response = $freeside->ip_login( array( 
  'mac' => $mac['mac_address'],
) );

$error = $response['error'];

if ( $error ) {

  $title ='Login'; include('elements/header.php');
  include('elements/error.php');	
  echo "Sorry "+$error;

 // header('Location:index.php?username='. urlencode($mac).
 //                          '&domain='.   urlencode($domain).
 //                          '&email='.    urlencode($email).
 //                          '&error='.    urlencode($error)
 //       );

}
else {
  // sucessful login

  $session_id = $response['session_id'];
  $mac = $mac['mac_address'];

  error_log("[login] logged into freeside with ip=$ip and mac=$mac, setting cookie");

  setcookie('session_id', $session_id);

  $title ='IP Login';

  if ( $response['custnum'] || $response['svcnum'] ) {

    header("Location:payment_only_payment.php");
    die();

  }   

} //successfull login

?>

<? include('elements/footer.php'); ?>