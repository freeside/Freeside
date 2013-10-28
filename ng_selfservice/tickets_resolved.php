<? $title ='Resolved Tickets'; include('elements/header.php'); ?>
<? $current_menu = 'tickets_resolved.php'; include('elements/menu.php'); ?>
<?

$customer_info = $freeside->list_tickets( array(
  'session_id' => $_COOKIE['session_id'],
  'status'     => 'resolved',
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
