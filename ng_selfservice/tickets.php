<? $title ='Open Tickets'; include('elements/header.php'); ?>
<? $current_menu = 'tickets.php'; include('elements/menu.php'); ?>
<?

$customer_info = $freeside->customer_info( array(
  'session_id' => $_COOKIE['session_id'],
) );

if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($customer_info);

?>
<? include('elements/ticketlist.php'); ?>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
