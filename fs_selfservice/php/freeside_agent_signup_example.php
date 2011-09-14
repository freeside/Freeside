<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->new_agent( array(
  'agent'          => $_POST['agent'], #agent name

  'username'       => strtolower($_POST['username']),
  '_password'      => strtolower($_POST['password'])
) );

error_log("[new_agent] received response from freeside: $response");
$error = $response['error'];

if ( ! $error ) {

    // sucessful signup

    $session_id = $response['session_id'];

    error_log("[new_agent] signup up agent");

} else {

    // unsucessful signup

    error_log("[new_agent] signup error: $error");

    // display error message to user

}

?>
