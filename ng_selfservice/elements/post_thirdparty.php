<?
if ( $payment_results['error'] ) {
  // an error at this stage isn't meaningful to the user
  // but make sure it's logged
  error_log("[start_thirdparty] $error");
  $error = 'Internal error communicating with payment processor.';
  include('error.php');
} elseif ( isset($payment_results['url']) ) {
  $url = $payment_results['url'];
?>
<H3>Redirecting to payment processor...</H3>
<DIV STYLE="display:none">
<FORM ID="autoform" METHOD="POST" ENCTYPE="multipart/form-data" ACTION="<?
  echo($url);
?>">
<?
if (isset($payment_results['post_params'])) {
  foreach ($payment_results['post_params'] as $key => $value) {
    echo("<INPUT TYPE=\"hidden\" NAME=\"$key\" VALUE=\"$value\">\n");
  }
} ?>
  <INPUT TYPE="submit" VALUE="submit">
</FORM>
</DIV>
<SCRIPT TYPE="text/javascript">
window.onload = function() {
  document.getElementById('autoform').submit();
}
</SCRIPT>
<? } else {
  $error = 'Internal error: no redirect URL.';
} ?>
