<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$session_id = $_POST['session_id'];

$response = $freeside->new_customer( array(
  'session_id' => $session_id,

  'first'          => $_POST['first'],
  'last'           => $_POST['last'],
  'address1'       => $_POST['address1'],
  'address2'       => $_POST['address2'],
  'city'           => $_POST['city'],
  'state'          => $_POST['state'],
  'zip'            => $_POST['zip'],
  'country'        => 'US',
  'daytime'        => $_POST['daytime'],
  'fax'            => $_POST['fax'],

  'payby'          => 'BILL',
  'invoicing_list' => $_POST['email'],

  'pkgpart'        => 2,
  'username'       => strtolower($_POST['username']),
  '_password'      => strtolower($_POST['password'])
) );

error_log("[new_customer] received response from freeside: $response");
$error = $response['error'];

if ( ! $error ) {

    // sucessful signup

    $custnum = $response['custnum'];

    error_log("[new_customer] signup up with custnum $custnum");

} else {

    // unsucessful signup

    error_log("[new_customer] signup error:: $error");

    // display error message to user

}

?>
