<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$ip = $_SERVER['REMOTE_ADDR'];

if ($_POST['domain'] == "ip_mac") {
  $mac_addr = $freeside->get_mac_address( array('ip' => $ip, ) );
  $_POST['username'] = $mac_addr['mac_address'];
}

$response = $freeside->login( array( 
  'email'    => strtolower($_POST['email']),
  'username' => strtolower($_POST['username']),
  'domain'   => strtolower($_POST['domain']),
  'password' => $_POST['password'],
) );

#error_log("[login] received response from freeside: $response");

$error = $response['error'];

if ( $error ) {

  header('Location:index.php?username='. urlencode($_POST['username']).
                           '&domain='.   urlencode($_POST['domain']).
                           '&email='.    urlencode($_POST['email']).
                           '&error='.    urlencode($error)
        );
  die();

}

// sucessful login

$session_id = $response['session_id'];

error_log("[login] logged into freeside with session_id=$session_id, setting cookie");

// now what?  for now, always redirect to the main page.
// eventually, other options?

setcookie('session_id', $session_id);

header("Location:main.php");
#die();

?>