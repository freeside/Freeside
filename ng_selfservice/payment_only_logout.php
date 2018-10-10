<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->ip_logout( array(
  'session_id' => $_COOKIE['session_id'],
) );

setcookie('session_id', '', time() - 3600);

$error = $response['error'];

if ( $error ) {
  error_log("Logout error: $error ");
}

?>

<!DOCTYPE html>
<HTML>
  <HEAD>
    <TITLE>
      Logged Out
    </TITLE>
    <link href="css/default.css" rel="stylesheet" type="text/css"/>
    <script type="text/javascript" src="js/jquery.js"></script>
    <script type="text/javascript" src="js/menu.js"></script>
  </HEAD>
  <BODY>
    <FONT SIZE=5>Logged Out</FONT>
    <BR><BR>
    You have been logged out.  
  </BODY>
</HTML>