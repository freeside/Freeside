<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );
get_header();

$freeside = new FreesideSelfService();

$login_info = $freeside->login_info();

extract($login_info);

$error = $_GET['error'];
if ( $error ) {
  $username = $_GET['username'];
  $email    = $_GET['email'];
  $domain   = $_GET['domain'];
}

?>
<?php include(dirname(__FILE__).'/elements/error.php'); ?>

<FORM ACTION="process_login.php" METHOD=POST>
<INPUT TYPE="hidden" NAME="session" VALUE="login">

<TABLE BGCOLOR="#c0c0c0" BORDER=0 CELLSPACING=2 CELLPADDING=0>

<?php if ( $single_domain ) { ?>

  <TR>
    <TH ALIGN="right">Username </TH>
    <TD>
      <INPUT TYPE="text" NAME="freeside_username" VALUE="<?php echo htmlspecialchars($username); ?>"><?php if ( $single_domain ) { echo '@'.$single_domain; } ?>
    </TD>
  </TR>

  <INPUT TYPE="hidden" NAME="freeside_domain" VALUE="<?php echo $single_domain ?>">

<?php } else { ?>

  <TR>
    <TH ALIGN="right">Email address </TH>
    <TD>
      <INPUT TYPE="text" NAME="freeside_email" VALUE="<?php echo htmlspecialchars($email); ?>">
    </TD>
  </TR>

<?php } ?>

<TR>
  <TH ALIGN="right">Password </TH>
  <TD>
    <INPUT TYPE="password" NAME="freeside_password">
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
<?php get_footer(); ?>

