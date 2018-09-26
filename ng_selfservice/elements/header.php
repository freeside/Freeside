<?

require_once('session.php');

$page = basename($_SERVER['SCRIPT_FILENAME']);

$access = $freeside->check_access( array(
  'session_id' => $_COOKIE['session_id'],
  'page'       => $page,
) );

if ($access['error']) {
  header('Location:no_access.php?error='. urlencode($access['error']));
  die();
}

?>

<!DOCTYPE html>
<HTML>
  <HEAD>
    <TITLE>
      <? echo $title; ?>
    </TITLE>
    <link href="css/default.css" rel="stylesheet" type="text/css"/>
    <script type="text/javascript" src="js/jquery.js"></script>
    <script type="text/javascript" src="js/menu.js"></script>
  </HEAD>
  <BODY>
    <FONT SIZE=5><? echo $title; ?></FONT>
    <BR><BR>

