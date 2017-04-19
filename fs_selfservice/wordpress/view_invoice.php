<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

$freeside = new FreesideSelfService();

$invoice_info = $freeside->invoice( array(
  'session_id' => $_COOKIE['freeside_session_id'],
  'invnum'     => $_REQUEST['invnum'],
) );


if ( isset($invoice_info['error']) && $invoice_info['error'] ) {
  $error = $invoice_info['error'];
  wp_redirect('example_login.php?freeside_error='. urlencode($error));
  die();
}

extract($invoice_info);

//if we don't need multi-company logo support, this is probably easier than
// calling invoice_logo()
$invoice_html = preg_replace( '/cust_bill-logo\.cgi\?invnum=\d+;template=/',
                              'mylogo.png?',
                              $invoice_html
                            );

get_header();

?>

<h3>Invoice</h3>

<?php echo $invoice_html ?>

<?php get_footer(); ?>

