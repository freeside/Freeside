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

get_header();

?>

<h3>Invoice</h3>

<?php echo $invoice_html ?>

<?php get_footer(); ?>

