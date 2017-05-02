<? $title ='Change Package'; include('elements/header.php'); ?>
<? $current_menu = 'services.php'; include('elements/menu.php'); ?>
<?

$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['session_id'],
) );

$list_pkgs = $freeside->list_pkgs( array(
  'session_id' => $_COOKIE['session_id'],
) );

if ( isset($list_pkgs['error']) && $list_pkgs['error'] ) {
  $error = $list_pkgs['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($list_pkgs);

$get_params = array( 'pkgnum', 'pkg' );
foreach ( $get_params AS $param ) {
  $params[$param] = $_GET[$param];
}

$pkgnum = $_GET['pkgnum'];
$pkg = $_GET['pkg'];

$pkgselect = $freeside->mason_comp( array(
    'session_id' => $_COOKIE['session_id'],
    'comp'       => '/elements/select-part_pkg.html',
    'args'       => array( 'custnum' => $customer_info['custnum'],
                           'curr_value' => 'current_value',
                    ),
  )
);

if ( isset($pkgselect['error']) && $pkgselect['error'] ) {
  $error = $pkgselect['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

?>

<SCRIPT TYPE="text/javascript">
function enable_change_pkg () {
  if ( document.ChangePkgForm.pkgpart_svcpart.selectedIndex > 0 ) {
    document.ChangePkgForm.submit.disabled = false;
  } else {
    document.ChangePkgForm.submit.disabled = true;
  }
}
</SCRIPT>

<FONT SIZE=4>Purchase replacement package for "<? echo $pkg; ?>"</FONT><BR><BR>

<? include('elements/error.php'); ?>

<FORM NAME="ChangePkgForm" ACTION="process_packages_change.php" METHOD=POST>
<TABLE BGCOLOR="#cccccc" BORDER=0 CELLSPACING=0>

<TR>
  <TD COLSPAN=2>
    <TABLE><TR><TD> <? echo $pkgselect['output']; ?>

  </TD>
</TR>

</TABLE>
<BR>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<? echo $customer_info['custnum'] ?>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<? echo $params['pkgnum'] ?>">
<INPUT TYPE="hidden" NAME="pkg" VALUE="<? echo $params['pkg'] ?>">
<INPUT TYPE="hidden" NAME="action" VALUE="process_change_pkg">
<INPUT NAME="submit" TYPE="submit" VALUE="Change Package">
</FORM>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>