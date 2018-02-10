<? if ($ach_read_only) { $bgShade = 'BGCOLOR="#ffffff"';  } ?>
<TR>
  <TD ALIGN="right">Account&nbsp;type</TD>
  <TD <? echo $bgShade; ?>>
    <? if ($ach_read_only) { echo htmlspecialchars($paytype); ?>
      <INPUT TYPE="hidden" NAME="paytype" VALUE="<? echo $paytype; ?>">
    <? } else { ?>
     <SELECT NAME="paytype">
      <? foreach ( $paytypes AS $pt ) { ?>
           <OPTION <? if ($pt == $paytype ) { echo 'SELECTED'; } ?> VALUE="<? echo $pt; ?>"><? echo $pt; ?>
      <? } ?>
     </SELECT>
    <? } ?>
  </TD>
</TR><TR>
  <TD ALIGN="right">Account&nbsp;number</TD>
  <TD <? echo $bgShade; ?>>
    <? if ($ach_read_only) { echo htmlspecialchars($payinfo1); ?>
      <INPUT TYPE="hidden" NAME="payinfo1" VALUE="<? echo $payinfo1; ?>">
    <? } else { ?>
      <INPUT TYPE="text" NAME="payinfo1" SIZE=10 MAXLENGTH=20 VALUE="<? echo $payinfo1; ?>">
    <? } ?>
  </TD>
</TR><TR>
  <TD ALIGN="right">ABA/Routing&nbsp;number</TD>
  <TD <? echo $bgShade; ?>>
    <? if ($ach_read_only) { echo htmlspecialchars($payinfo2); ?>
      <INPUT TYPE="hidden" NAME="payinfo2" VALUE="<? echo $payinfo2; ?>">
    <? } else { ?>
      <INPUT TYPE="text" NAME="payinfo2" SIZE=10 MAXLENGTH=9 VALUE="<? echo $payinfo2; ?>"></TD>
    <? } ?>
</TR><TR>
  <TD ALIGN="right">Bank&nbsp;name</TD>
  <TD <? echo $bgShade; ?>>
    <? if ($ach_read_only) { echo htmlspecialchars($payname); ?>
      <INPUT TYPE="hidden" NAME="payname" VALUE="<? echo $payname; ?>"></TD>
    <? } else { ?>
      <INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<? echo $payname; ?>"></TD>
    <? } ?>
</TR><TR>

  <? if ($show_paystate) { ?>
    <TR>
      <TD ALIGN="right">Bank state</TD>
      <TD <? echo $bgShade; ?>>
      <? if ($ach_read_only) { echo htmlspecialchars($paystate); ?>
        <INPUT TYPE="hidden" NAME="paystate" VALUE="<? echo $paystate; ?>"></TD>
      <? } else { ?>
        <SELECT NAME="paystate">
          <? foreach ( $states AS $s ) { ?>
            <OPTION <? if ($s == $paystate ) { echo 'SELECTED'; } ?>><? echo $s; ?>
          <? } ?>
        </SELECT></TD>
      <? } ?>
    </TR>
  <? } ?>

  <? if ($show_ss) { ?>
    <TR>
      <TD ALIGN="right">Account&nbsp;holder<BR>Social&nbsp;security&nbsp;or&nbsp;tax&nbsp;ID&nbsp;#</TD>
      <TD <? echo $bgShade; ?>>
      <? if ($ach_read_only) { echo htmlspecialchars($ss); ?>
        <INPUT TYPE="hidden" NAME="ss" VALUE="<? echo $ss; ?>"></TD>
      <? } else { ?>
        <INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="ss" VALUE="<? echo $ss; ?>"></TD>
      <? } ?>
    </TR>
  <? } ?>

  <? if ($show_stateid) { ?>
    <TR>
      <TD ALIGN="right">Account&nbsp;holder<BR><? echo $stateid_label; ?></TD>
      <TD <? echo $bgShade; ?>>
      <? if ($ach_read_only) { echo htmlspecialchars($stateid); ?>
        <INPUT TYPE="hidden" NAME="stateid" VALUE="<? echo $stateid; ?>"></TD>
        <TD <? echo $bgShade; ?>> <? echo $stateid_state; ?>
          <INPUT TYPE="hidden" NAME="stateid_state" VALUE="<? echo $stateid_state; ?>"></TD>
      <? } else { ?>
        <INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="stateid" VALUE="<? echo $stateid; ?>"></TD>
        <TD ALIGN="right"><? echo $stateid_state_label; ?></TD>
        <TD><SELECT NAME="stateid_state">
          <? foreach ( $states AS $s ) { ?>
            <OPTION <? if ($s == $stateid_state ) { echo 'SELECTED'; } ?>><? echo $s; ?>
          <? } ?>
        </SELECT></TD>
      <? } ?>
    </TR>
  <? } ?>
