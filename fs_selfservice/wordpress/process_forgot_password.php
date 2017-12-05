<?php

require( dirname( __FILE__ ) . '/wp-blog-header.php' );
get_header();

$freeside = new FreesideSelfService();

if ( isset($_POST['freeside_session_id']) ) {

    $result = $freeside->process_reset_passwd(array(
      'session_id'    => $_POST['freeside_session_id'],
      'new_password'  => $_POST['new_password'],
      'new_password2' => $_POST['new_password2'],
    ));

    if ( $result['error'] ) {
      $_REQUEST['freeside_error'] = $result['error'];
      $freeside_session_id = htmlspecialchars($_POST['freeside_session_id']);
    } 

?>

    <?php include('elements/error.php'); ?>

    <?php if ( ! $result['error'] ) { ?>

        Your password has been changed.  You can now <A HREF="example_login.php">log in</A>.

    <?php get_footer(); die; ?>
    <?php } ?>

<?php 
} elseif ( isset($_GET['action']) ) {

    $freeside_session_id = '';
    $matches = array();
    if ( preg_match( '/^process_forgot_password_session_(\w+)$/', $_GET['action'], $matches ) ) {
      $freeside_session_id = $matches[1];
    } else {
      #shouldn't be at this URL w/o action; accidentally edited URL or malicious
      die();
    }
?>

<?php } ?>

    <FORM METHOD="POST">
    <INPUT TYPE="hidden" NAME="freeside_session_id" VALUE="<?php echo $freeside_session_id; ?>">
    New password: <INPUT TYPE="password" NAME="new_password"><BR>

    Re-enter new password: <INPUT TYPE="password" NAME="new_password2"><BR>

    <INPUT TYPE="submit" VALUE="Change password">
    </FORM>


<?php get_footer(); ?>
