<?

require_once('elements/session.php');

$xmlrpc_args = array(
  fieldid        => $_POST['fieldid'],
  check_password => $_POST['check_password'],
  svcnum         => $_POST['svcnum'],
  session_id     => $_COOKIE['session_id']
);

$result = $freeside->validate_passwd($xmlrpc_args);
echo json_encode($result);

?>
