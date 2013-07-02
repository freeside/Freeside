<?

require_once('elements/session.php');

if ( $_POST['ticket_id'] ) {
  $ticket_id = $_POST['ticket_id'];
} else {
  $ticket_id = $_SERVER['QUERY_STRING'];
}

if ( ! preg_match( '/^\d+$/', $ticket_id ) ) {
  header('Location:index.php?error=No+ticket+ID');
  die();
}

$ticket_info = $freeside->get_ticket( array(
  'session_id' => $_COOKIE['session_id'],
  'ticket_id'  => $ticket_id,
  'subject'    => $_POST['subject'],
  'reply'      => $_POST['reply'],
) );

if ( isset($ticket_info['error']) && $ticket_info['error'] ) {
  $error = $ticket_info['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($ticket_info);

?>
<? $title = "View ticket #$ticket_id"; include('elements/header.php'); ?>
<? $current_menu = 'tickets.php'; include('elements/menu.php'); ?>

<TABLE>
<? foreach ( $transactions AS $transaction ) {
     if ( $transaction['content'] == 'This transaction appears to have no content' ) { continue; }
?>
    <TR>
      <TD>
        <B>
          <? echo $transaction['created'] ?>
          &nbsp;
          <? echo $transaction['description'] ?>
        </B>
        <PRE><? echo $transaction['content'] ?></PRE><BR>
      </TD>
    </TR>
<? } ?>
</TABLE>

<BR><BR>
<FORM ACTION="ticket.php" METHOD=POST>
    <input type="hidden" name="ticket_id" value="<? echo $ticket_id ?>">

<? if ( $edit_ticket_subject ) { ?>
    Subject:<BR><input type="text" name="subject" value="<? htmlspecialchars($ticket_fields['subject']) ?>" style="width:440px">
    <BR><BR>
<? } ?>

    Add reply to ticket:
    <BR>
    <textarea name="reply" cols="60" rows="10" style="width:440px"></textarea>
    <BR><input type="submit" value="Reply">
</form>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
