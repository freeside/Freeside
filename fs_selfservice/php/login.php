<?php

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
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD><TITLE>Login</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=5>Login</FONT><BR><BR>
<FONT SIZE="+1" COLOR="#ff0000"><?php echo htmlspecialchars($error); ?></FONT>

<FORM ACTION="process_login.php" METHOD=POST>
<INPUT TYPE="hidden" NAME="session" VALUE="login">

<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>

<TR>
  <TH ALIGN="right">Username </TH>
  <TD>
    <INPUT TYPE="text" NAME="username" VALUE="<?php echo htmlspecialchars($username); ?>"><?php if ( $single_domain ) { echo '@'.$single_domain; } ?>
  </TD>
</TR>

<?php if ( $single_domain ) { ?>

  <INPUT TYPE="hidden" NAME="domain" VALUE="<?php echo $single_domain ?>">

<?php } else { ?>

  <TR>
    <TH ALIGN="right">Domain </TH>
    <TD>
      <INPUT TYPE="text" NAME="domain" VALUE="<?php echo htmlspecialchars($domain); ?>">
    </TD>
  </TR>

<?php } ?>

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

<?php if ( $phone_login ) { ?>

  <B>OR</B><BR><BR>
    
  <FORM ACTION="process_login.php" METHOD=POST>
  <INPUT TYPE="hidden" NAME="session" VALUE="login">
  <TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>
  <TR>
    <TH ALIGN="right">Phone number </TH>
    <TD>
      <INPUT TYPE="text" NAME="username" VALUE="<?php echo htmlspecialchars($username) ?>">
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

<?php } ?>

</BODY></HTML>

