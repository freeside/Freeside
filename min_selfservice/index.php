<?
  $error = $_GET['error'];
  if ( $error ) {
    $username = $_GET['username'];
    $domain   = $_GET['domain'];
    $title ='Login Error'; 
    include('elements/header.php');
    include('elements/error.php');
?>
    <TABLE BORDER=0 CELLSPACING=2 CELLPADDING=0>
      <TR>
        <TD>
          Sorry we were unable to locate your account with ip <? echo $username; ?>  .
        </TD>
      </TR>
    </TABLE>
<?
    include('elements/footer.php');
  }
  else { include('login.php'); }
?>

<? #include('login.php'); ?>


<?
#require('freeside.class.php');
#$freeside = new FreesideSelfService();
#
#$login_info = $freeside->login_info();
#
#extract($login_info);
#
#$error = $_GET['error'];
#if ( $error ) {
#  $username = $_GET['username'];
#  $domain   = $_GET['domain'];
#}

?>