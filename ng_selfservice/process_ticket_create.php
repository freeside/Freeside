<?

require_once('elements/session.php');

$ticket_info = $freeside->create_ticket(array(
  'session_id' => $_COOKIE['session_id'],
  'requestor'  => $_POST['requestor'],
  'subject'    => $_POST['subject'],
  'message'    => $_POST['message'],
));

if ( isset($ticket_info['error']) && $ticket_info['error'] ) {
  $error = $ticket_info['error'];
  header('Location:ticket_create.php?error='. urlencode($error));
  die();
}

$ticket_id = $ticket_info['ticket_id'];

header("Location:ticket.php?".$ticket_id)

?>
