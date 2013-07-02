<? $title ='Create a new ticket'; include('elements/header.php'); ?>
<? $current_menu = 'ticket_create.php'; include('elements/menu.php'); ?>
<?

$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['session_id'],
) );

if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

//extract($customer_info);

$invoicing_list = preg_split('/\s*,\s*/', $customer_info['invoicing_list'] );
$requestor = $invoicing_list[0];

$error = $_GET['error'];

?>

    Please fill in both the subject and message.  Please provide as much information as possible.  This will enable us to help you quickly.
    <br><br>

    <? include('elements/error.php'); ?>

    <FORM ACTION="process_ticket_create.php" METHOD=POST>
    <table>
	<tr>
	    <td>From</td>
	    <td><b><? echo htmlspecialchars($requestor) ?></b></td>
	</tr>
	<tr>
	    <td>Subject</td>
	    <td><input type="text" name="subject" size="54"></td>
	</tr>
	<tr>
	    <td valign="top">Message</td>
	    <td><textarea name="message" rows="16" cols="72"></textarea></td>
	</tr>
	<tr>
	    <td></td>
	    <td><input type="submit" value="Create"></td>
	</tr>
    </table>
    </form> 

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
