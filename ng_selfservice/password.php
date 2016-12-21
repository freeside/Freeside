<? $title ='Change Password'; include('elements/header.php'); ?>
<? $current_menu = 'password.php'; include('elements/menu.php'); ?>
<?
$error = '';
$pwd_change_success = false;
if ( isset($_POST['svcnum']) ) {

  $pwd_change_result = $freeside->myaccount_passwd(array(
    'session_id'    => $_COOKIE['session_id'],
    'svcnum'        => $_POST['svcnum'],
    'new_password'  => $_POST['new_password'],
    'new_password2' => $_POST['new_password2'],
  ));

  if ($pwd_change_result['error']) {
    $error = $pwd_change_result['error'];
  } else {
    $pwd_change_success = true;
  }
}

if ($pwd_change_success) {
?>

<P>Password changed for <? echo $pwd_change_result['value'],' ',$pwd_change_result['label'] ?>.</P>

<?
} else {
  $pwd_change_svcs = $freeside->list_svcs(array(
    'session_id' => $_COOKIE['session_id'],
    'svcdb'      => 'svc_acct',
  ));
  if (isset($pwd_change_svcs['error'])) {
    $error = $error || $pwd_change_svcs['error'];
  }
  if (!isset($pwd_change_svcs['svcs'])) {
    $pwd_change_svcs['svcs'] = $pwd_change_svcs['svcs'];
    $error = $error || 'Unknown error loading services';
  }
  if ($error) {
    include('elements/error.php');
  }
?>

<FORM METHOD="POST">
<TABLE BGCOLOR="#cccccc">
  <TR>
    <TH ALIGN="right">Change password for account: </TH>
    <TD>
      <SELECT ID="new_password_svcnum" NAME="svcnum">
<?
  $selected_svcnum = isset($_POST['svcnum']) ? $_POST['svcnum'] : $pwd_change_svcs['svcnum'];
  foreach ($pwd_change_svcs['svcs'] as $svc) {
?>
        <OPTION VALUE="<? echo $svc['svcnum'] ?>"<? echo $selected_svcnum == $svc['svcnum'] ? ' SELECTED' : '' ?>>
          <? echo $svc['label'],': ',$svc['value'] ?>
        </OPTION>
<?
  }
?>
      </SELECT>
    </TD>
  </TR>

  <TR>
    <TH ALIGN="right">New password: </TH>
    <TD>
      <INPUT ID="new_password" TYPE="password" NAME="new_password" SIZE="18">
      <DIV ID="new_password_result"></DIV>
<? include('elements/add_password_validation.php'); ?>
      <SCRIPT>add_password_validation('new_password');</SCRIPT>
    </TD>
  </TR>

  <TR>
    <TH ALIGN="right">Re-enter new password: </TH>
    <TD><INPUT TYPE="password" NAME="new_password2" SIZE="18"></TD>
  </TR>

</TABLE>
<BR>

<INPUT TYPE="submit" VALUE="Change password">

</FORM>

<?
} // end if $pwd_change_show_form
?>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
