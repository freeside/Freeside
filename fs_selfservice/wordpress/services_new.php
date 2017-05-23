<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );

$freeside = new FreesideSelfService();

if ( isset($_POST['pkgpart_svcpart']) && $_POST['pkgpart_svcpart'] ) {

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
      'session_id' => $_COOKIE['freeside_session_id'],
    );

    foreach ( $params AS $param ) {
      $order_pkg[$param] = $_POST[$param];
    }

    $results = $freeside->order_pkg($order_pkg);

  }

  if ( isset($results['error']) && $results['error'] ) {
    $_REQUEST['freeside_error'] = $results['error'];
  } else {
    #$pkgnum = $results['pkgnum'];
    #wp_redirect("services.php"); # #pkgnum ?
    #wp_redirect("service_order_success.php"); # #pkgnum ?
    wp_redirect("example_selfservice.php"); # #pkgnum ?
    die();
  }

}

$pkgselect = $freeside->mason_comp( [
    'session_id' => $_COOKIE['freeside_session_id'],
    'comp'       => '/edit/cust_main/first_pkg/select-part_pkg.html',
    'args'       => [ 'password_verify', 1,
                      'onchange'       , 'enable_order_pkg()',
                      #'relurls'        , 1,
                      'empty_label'    , 'Select package',
                      'form_name'      , 'OrderPkgForm',
                      'pkgpart_svcpart', $_POST['pkgpart_svcpart'],
                      'username'       , $_POST['username'],
                      'password'       , $_POST['_password'],
                      'password2'      , $_POST['_password2'],
                      'popnum'         , $_POST['popnum'],
                      'saved_domsvc'   , $_POST['domsvc'],
                    ],
]);

get_header();

?>

<h3>Order a new service</h3>

<SCRIPT TYPE="text/javascript">
function enable_order_pkg () {
  if ( document.OrderPkgForm.pkgpart_svcpart.selectedIndex > 0 ) {
    document.OrderPkgForm.submit.disabled = false;
  } else {
    document.OrderPkgForm.submit.disabled = true;
  }
}
</SCRIPT>

<?php include(dirname(__FILE__).'/elements/error.php'); ?>

<FORM NAME="OrderPkgForm" ACTION="services_new.php" METHOD=POST>

<?php echo $pkgselect['output']; ?>

<BR>
<INPUT NAME="submit" TYPE="submit" VALUE="Purchase" <?php if ( ! $_POST['pkgpart_svcpart'] ) { echo 'DISABLED'; } ?>>
</FORM>

<?php get_footer(); ?>
