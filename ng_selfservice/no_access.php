<!DOCTYPE html>
<HTML>
  <HEAD>
    <TITLE>
      Access Denied
    </TITLE>
    <link href="css/default.css" rel="stylesheet" type="text/css"/>
    <script type="text/javascript" src="js/jquery.js"></script>
    <script type="text/javascript" src="js/menu.js"></script>
  </HEAD>
  <BODY>
    <FONT SIZE=5>Access Denied</FONT>
    <BR><BR>
<? $current_menu = 'no_access.php'; include('elements/menu.php'); ?>
<?

$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['session_id'],
) );

if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($customer_info);

?>

<P>Sorry you do not have access to the page you are trying to reach.</P>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>