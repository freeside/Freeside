<? require('elements/session.php');

$args = array(
    'session_id' => $_COOKIE['session_id'],
    'format'     => 'pdf'
);

$results = $freeside->quotation_print($args);
if ( isset($results['document']) ) {
    header('Content-Type: application/pdf');
    header('Content-Disposition: filename=quotation.pdf');
    print($results['document']->scalar);
} else {
    header("Location: quotation.php?error=" . $results['error']);
}

?>
