<?

require_once('elements/session.php');

$results = array();

$params = array( 'custnum', 'pkgpart' );

$matches = array();
if ( preg_match( '/^(\d+)_(\d+)$/', $_POST['pkgpart_svcpart'], $matches ) ) {
  $_POST['pkgpart'] = $matches[1];
  $_POST['svcpart'] = $matches[2];
  $params[] = 'svcpart';
  $svcdb = $_POST['svcdb'];
  if ( $svcdb == 'svc_acct' ) { $params[] = 'domsvc'; }
} else {
  $svcdb = 'svc_acct';
}

if ( $svcdb == 'svc_acct' ) {

  array_push($params, 'username', '_password', '_password2', 'sec_phrase', 'popnum' );

  if ( strlen($_POST['_password']) == 0 ) {
    $results['error'] = 'Empty password';
  }
  if ( $_POST['_password'] != $_POST['_password2'] ) {
    $results['error'] = 'Passwords do not match';
    $_POST['_password'] = '';
    $_POST['_password2'] = '';
  }

} elseif ( $svcdb == 'svc_phone' ) {

  array_push($params, 'phonenum', 'sip_password', 'pin', 'phone_name' );

} else {
  die("$svcdb not handled on process_order_pkg yet");
}

if ( ! $results['error'] ) {

  $order_pkg = array(
    'session_id' => $_COOKIE['session_id'],
  );

  foreach ( $params AS $param ) {
    $order_pkg[$param] = $_POST[$param];
  }

  $results = $freeside->order_pkg($order_pkg);

}

#  if ( $results->{'error'} ) {
#    $action = 'customer_order_pkg';
#    return {
#      $cgi->Vars,
#      %{customer_order_pkg()},
#      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
#    };
#  } else {
#    return $results;
#  }

if ( isset($results['error']) && $results['error'] ) {
  $error = $results['error'];
  header('Location:services_new.php?error='. urlencode($error));
  die();
}

#$pkgnum = $results['pkgnum'];

header("Location:services.php"); # #pkgnum ?

?>
