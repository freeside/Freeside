<?php

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->login( array( 
  'username' => strtolower($_POST['username']),
  'domain'   => strtolower($_POST['domain']),
  'password' => $_POST['password'],
) );

#error_log("[login] received response from freeside: $response");

$error = $response['error'];

if ( $error ) {

  header('Location:login.php?username='. urlencode($username).
                           '&domain='.   urlencode($domain).
                           '&error='.    urlencode($error)
        );
  die();

}

// sucessful login

$session_id = $response['session_id'];

#error_log("[login] logged into freeside with session_id=$session_id");

// now what?  for now, always redirect to the main page.
// eventually, other options?

header("Location:main.php?session_id=$session_id")
#die();

?>
