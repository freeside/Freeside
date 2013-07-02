<TR>
  <TD ALIGN="right">Account&nbsp;type</TD>
  <TD>
    <SELECT NAME="paytype">
      <? foreach ( $paytypes AS $pt ) { ?>
           <OPTION <? if ($pt == $paytype ) { echo 'SELECTED'; } ?> VALUE="<? echo $pt; ?>"><? echo $pt; ?>
      <? } ?>
    </SELECT>
  </TD>
</TR><TR>
  <TD ALIGN="right">Account&nbsp;number</TD>
  <TD><INPUT TYPE="text" NAME="payinfo1" SIZE=10 MAXLENGTH=20 VALUE="<? echo $payinfo1; ?>"></TD>
</TD><TR>
  <TD ALIGN="right">ABA/Routing&nbsp;number</TD>
  <TD><INPUT TYPE="text" NAME="payinfo2" SIZE=10 MAXLENGTH=9 VALUE="<? echo $payinfo2; ?>"></TD>
</TR><TR>
  <TD ALIGN="right">Bank&nbsp;name</TD>
  <TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<? echo $payname; ?>"></TD>
</TR><TR>

  <? if ($show_paystate) { ?>
       <TD ALIGN="right">Bank state</TD>
       <TD>
         <SELECT NAME="paystate">
           <? foreach ( $states AS $s ) { ?>
              <OPTION <? if ($s == $paystate ) { echo 'SELECTED'; } ?>><? echo $s; ?>
           <? } ?>
         </SELECT>
       </TD>
       </TR><TR>
  <? } ?>

  <? if ($show_ss) { ?>
      <TD ALIGN="right">Account&nbsp;holder<BR>Social&nbsp;security&nbsp;or&nbsp;tax&nbsp;ID&nbsp;#</TD><TD>
      <INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="ss" VALUE="<? echo $ss; ?>">
      </TD></TR><TR>
  <? } ?>

  <? if ($show_stateid) { ?>
      <TD ALIGN="right">
      Account&nbsp;holder<BR><? echo $stateid_label; ?></TD><TD>
      <INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="stateid" VALUE="<? echo $stateid; ?>"></TD>
      <TD ALIGN="right"><? echo $stateid_state_label; ?></TD>
      <TD><SELECT NAME="stateid_state">
      <? foreach ( $states AS $s ) { ?>
           <OPTION <? if ($s == $stateid_state ) { echo 'SELECTED'; } ?>><? echo $s; ?>
      <? } ?>
      </SELECT></TD></TR><TR>
  <? } ?>
</TR>
