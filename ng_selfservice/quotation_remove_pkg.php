<? require('elements/session.php');

$dest = 'quotation.php';

if ( isset($_REQUEST['pkgnum']) ) {

  $results = array();

  $params = array( 'custnum', 'pkgnum' );

  $matches = array();
  if ( preg_match( '/^(\d+)$/', $_REQUEST['pkgnum'] ) ) {

    $args = array(
        'session_id' => $_COOKIE['session_id'],
        'pkgnum'     => $_REQUEST['pkgnum'],
    );

    $results = $freeside->quotation_remove_pkg($args);

  }

  if ( isset($results['error']) && $results['error'] ) {
    $dest .= '?error=' . $results['error'];
  }

}

header("Location:$dest");

?>
