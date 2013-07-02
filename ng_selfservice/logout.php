<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$response = $freeside->logout( array(
  'session_id' => $_COOKIE['session_id'],
) );

setcookie('session_id', '', time() - 3600);

$error = $response['error'];

if ( $error ) {
  error_log("Logout error: $error; ignoring");
}

header('Location:index.php?error='.
         urlencode( _('You have been logged out.'). '  '.
                    _('Thank you for using the system.')
                  )
      );

?>
