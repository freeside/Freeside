<? $title ='Order a new service'; include('elements/header.php'); ?>
<? $current_menu = 'services_new.php'; include('elements/menu.php'); ?>
<?

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
      'session_id' => $_COOKIE['session_id'],
    );

    foreach ( $params AS $param ) {
      $order_pkg[$param] = $_POST[$param];
    }

    $results = $freeside->order_pkg($order_pkg);

  }

  #  if ( $results->{'error'} ) {
  #    $action = 'customer_order_pkg';
  #    return {
  #      $cgi->Vars,
  #      %{customer_order_pkg()},
  #      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
  #    };
  #  } else {
  #    return $results;
  #  }

  if ( isset($results['error']) && $results['error'] ) {
    $error = $results['error'];
  } else {
    #$pkgnum = $results['pkgnum'];
    header("Location:services.php"); # #pkgnum ?
    die();
  }

}

//sub customer_order_pkg {
//  my $init_data = signup_info( 'customer_session_id' => $session_id );
//  return $init_data if ( $init_data->{'error'} );
//
//  my $customer_info = customer_info( 'session_id' => $session_id );
//  return $customer_info if ( $customer_info->{'error'} );

$pkgselect = $freeside->mason_comp( array(
    'session_id' => $_COOKIE['session_id'],
    'comp'       => '/edit/cust_main/first_pkg/select-part_pkg.html',
    'args'       => array( 'password_verify', 1,
                           'onchange'       , 'enable_order_pkg()',
                           'relurls'        , 1,
                           'empty_label'    , 'Select package',
                           'form_name'      , 'OrderPkgForm',
                           'pkgpart_svcpart', $_POST['pkgpart_svcpart'],
                           'username'       , $_POST['username'],
                           'password'       , $_POST['_password'],
                           'password2'      , $_POST['_password2'],
                           'popnum'         , $_POST['popnum'],
                           'saved_domsvc'   , $_POST['domsvc'],
                         ),
));
if ( isset($pkgselect['error']) && $pkgselect['error'] ) {
  $error = $pkgselect['error'];
  header('Location:index.php?error='. urlencode($pkgselect));
  die();
}

//  return {
//    ( map { $_ => $init_data->{$_} }
//          qw( part_pkg security_phrase svc_acct_pop ),
//    ),
//    %$customer_info,
//    'pkg_selector' => $pkgselect,
//  };
//}

?>
<SCRIPT TYPE="text/javascript">
function enable_order_pkg () {
  if ( document.OrderPkgForm.pkgpart_svcpart.selectedIndex > 0 ) {
    document.OrderPkgForm.submit.disabled = false;
  } else {
    document.OrderPkgForm.submit.disabled = true;
  }
}
</SCRIPT>

<? include('elements/error.php'); ?>

<FORM NAME="OrderPkgForm" ACTION="services_new.php" METHOD=POST>
<TABLE BGCOLOR="#cccccc" BORDER=0 CELLSPACING=0>

<TR>
  <TD COLSPAN=2>
    <TABLE><TR><TD> <? echo $pkgselect['output']; ?>

  </TD>
</TR>

</TABLE>
<BR>
<INPUT NAME="submit" TYPE="submit" VALUE="Purchase" <? if ( ! $_POST['pkgpart_svcpart'] ) { echo 'DISABLED'; } ?>>
</FORM>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
