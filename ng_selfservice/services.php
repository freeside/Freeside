<? $title ='My Services'; include('elements/header.php'); ?>
<? $current_menu = 'services.php'; include('elements/menu.php'); ?>
<?

$list_pkgs = $freeside->list_pkgs( array(
  'session_id' => $_COOKIE['session_id'],
) );

if ( isset($list_pkgs['error']) && $list_pkgs['error'] ) {
  $error = $list_pkgs['error'];
  header('Location:index.php?error='. urlencode($error));
  die();
}

extract($list_pkgs);

?>
<TABLE BORDER=0 CELLSPACING=2 CELLPADDING=1>
<TR>
  <TH ALIGN="LEFT">Product</TH>
  <TH ALIGN="LEFT">Status</TH>
  <TH ALIGN="LEFT" COLSPAN=2>Service(s)</TH>
  <TH ALIGN="LEFT"></TH>
</TR>

<? foreach ( $cust_pkg AS $pkg ) {
    if ( $pkg['status'] == 'one-time charge' ) { continue; }
    //$link = '<A HREF="ticket.php?'. $ticket['id']. '">';
    $rowspan = count($pkg['cust_svc']);
    if ( $rowspan == 0 ) { $rowspan = 1; }
    $td = '<TD ALIGN="LEFT" VALIGN="top" ROWSPAN="'. $rowspan. '">';
?>
  <TR>
    <TD COLSPAN=4 STYLE="border-top:1px solid #999999"></TD>
  </TR>
  <TR>
    <? echo $td ?><? echo $pkg['pkg_label']; ?></TD>
    <? echo $td ?>
      <FONT COLOR="#<? echo $pkg['statuscolor'] ?>"><B>
        <? echo ucfirst($pkg['status']); ?>
      </B></FONT>
      <? if ( $pkg['status'] == 'active' && $pkg['bill'] ) { ?>
        - renews on <? echo date('M jS Y', $pkg['bill']); ?>
      <? } ?>
    </TD>
    <? $subsequent = 0;
       foreach ( $pkg['cust_svc'] AS $svc ) {
         $label  = $svc['label'][0];
         $value  = $svc['label'][1];
         $table  = $svc['label'][2];
         $svcnum = $svc['label'][3];
    ?>
       <? if ( $subsequent++ ) { echo '<TR>'; } ?>
         <TD ALIGN="right"><? echo $label ?>: </TD>
         <TD><? echo $value ?></TD>
       </TR>
    <? } ?>
<? } ?>

</TABLE>
<BR>

<!-- <A HREF="services_new.php">Order a new service</A> -->
<FORM ACTION="services_new.php">
<INPUT TYPE="submit" VALUE="Order a new service">
</FORM>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
