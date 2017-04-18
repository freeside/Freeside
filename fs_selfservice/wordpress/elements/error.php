<?php 
  $error = stripslashes_deep($_REQUEST['freeside_error']);
?>
<FONT SIZE="+1" COLOR="#ff0000"><?php echo htmlspecialchars($error); ?><?php if ($error) { echo '<BR><BR>'; } ?></FONT>

