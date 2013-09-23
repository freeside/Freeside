
<TABLE BORDER=0 CELLSPACING=2 CELLPADDING=1>
<TR>
  <TH ALIGN="LEFT">#</TH>
  <TH ALIGN="LEFT">Subject</TH>
  <TH ALIGN="LEFT">Queue</TH>
  <TH ALIGN="LEFT">Status</TH>
  <TH ALIGN="LEFT">Created</TH>
</TR>

<? foreach ( $tickets AS $ticket ) {
    $link = '<A HREF="ticket.php?'. $ticket['id']. '">';
?>
  <TR>
    <TD COLSPAN=5 STYLE="border-top:1px solid #999999"></TD>
  </TR>
  <TR>
    <TD ALIGN="right"><? echo $link ?><? echo $ticket['id']; ?></A></TD>
    <TD><? echo $link ?><? echo $ticket['subject']; ?></A></TD>
    <TD><? echo $ticket['queue']; ?></TD>
    <TD><? echo $ticket['status']; ?></TD>
    <TD><? echo $ticket['created']; ?></TD>
  </TR>
<? } ?>
<!-- some notification if there's new responses since your last login -->

</TABLE>
