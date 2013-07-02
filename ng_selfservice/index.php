<?

require('freeside.class.php');
$freeside = new FreesideSelfService();

$login_info = $freeside->login_info();

extract($login_info);

$error = $_GET['error'];
if ( $error ) {
  $username = $_GET['username'];
  $domain   = $_GET['domain'];
}

?>
<? $title ='Login'; include('elements/header.php'); ?>
<? include('elements/error.php'); ?>

<FORM ACTION="process_login.php" METHOD=POST>
<INPUT TYPE="hidden" NAME="session" VALUE="login">

<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>

<TR>
  <TH ALIGN="right">Username </TH>
  <TD>
    <INPUT TYPE="text" NAME="username" VALUE="<? echo htmlspecialchars($username); ?>"><? if ( $single_domain ) { echo '@'.$single_domain; } ?>
  </TD>
</TR>

<? if ( $single_domain ) { ?>

  <INPUT TYPE="hidden" NAME="domain" VALUE="<? echo $single_domain ?>">

<? } else { ?>

  <TR>
    <TH ALIGN="right">Domain </TH>
    <TD>
      <INPUT TYPE="text" NAME="domain" VALUE="<? echo htmlspecialchars($domain); ?>">
    </TD>
  </TR>

<? } ?>

<TR>
  <TH ALIGN="right">Password </TH>
  <TD>
    <INPUT TYPE="password" NAME="password">
  </TD>
</TR>
<TR>
  <TD COLSPAN=2 ALIGN="center"><INPUT TYPE="submit" VALUE="Login"></TD>
</TR>
</TABLE>
</FORM>

<? if ( $phone_login ) { ?>

  <B>OR</B><BR><BR>
    
  <FORM ACTION="process_login.php" METHOD=POST>
  <INPUT TYPE="hidden" NAME="session" VALUE="login">
  <TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>
  <TR>
    <TH ALIGN="right">Phone number </TH>
    <TD>
      <INPUT TYPE="text" NAME="username" VALUE="<? echo htmlspecialchars($username) ?>">
    </TD>
  </TR>
  <INPUT TYPE="hidden" NAME="domain" VALUE="svc_phone">
  <TR>
    <TH ALIGN="right">PIN </TH>
    <TD>
      <INPUT TYPE="password" NAME="password">
    </TD>
  </TR>
  <TR>
    <TD COLSPAN=2 ALIGN="center"><INPUT TYPE="submit" VALUE="Login"></TD>
  </TR>
  </TABLE>
  </FORM>

<? } ?>

<? include('elements/footer.php'); ?>


