<? require('elements/session.php');

$dest = 'services.php';

$args = array( 'session_id' => $_COOKIE['session_id'] );

$results = $freeside->quotation_order($args);

if ( isset($results['error']) && $results['error'] ) {
    $dest = 'quotation.php?error=' . $results['error'];
}

header("Location:$dest");

?>
