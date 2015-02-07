<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->switch_cust( array( 
  'session_id' => $_COOKIE['session_id'],
  'custnum'    => $_POST['custnum'],
) );

#error_log("[switch_cust] received response from freeside: $response");

$error = $response['error'];

if ( $error ) {

  //this isn't well handled... but the only possible error is a session timeout?

  header('Location:index.php?username='. urlencode($username).
                           '&domain='.   urlencode($domain).
                           '&email='.    urlencode($email).
                           '&error='.    urlencode($error)
        );
  die();

}

// sucessful customer selection

header("Location:main.php");

?>
