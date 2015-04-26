<? require('elements/session.php');

$dest = 'quotation.php';

if ( isset($_REQUEST['pkgpart']) ) {

  $results = array();

  $params = array( 'custnum', 'pkgpart' );

  $matches = array();
  if ( preg_match( '/^(\d+)$/', $_REQUEST['pkgpart'] ) ) {

    $args = array(
        'session_id' => $_COOKIE['session_id'],
        'pkgpart'    => $_REQUEST['pkgpart'],
    );

    $results = $freeside->quotation_add_pkg($args);

  }

  if ( isset($results['error']) && $results['error'] ) {
    $dest .= '?error=' . $results['error'] . ';pkgpart=' . $_REQUEST['pkgpart'];
  }
}

header("Location:$dest");

?>

