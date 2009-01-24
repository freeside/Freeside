<?php

require('freeside.class.php');
$freeside = new FreesideSelfService();

$session_id = $_GET['session_id'];

$renew_info = $freeside->renew_info( array(
  'session_id' => $session_id,
) );

$error = $renew_info['error'];

if ( $error ) {
  header('Location:login.php?error='. urlencode($error));
  die();
}

#in the simple case, just deal with the first package
$bill_date         = $renew_info['dates'][0]['bill_date'];
$bill_date_pretty  = $renew_info['dates'][0]['bill_date_pretty'];
$renew_date        = $renew_info['dates'][0]['renew_date'];
$renew_date_pretty = $renew_info['dates'][0]['renew_date_pretty'];
$amount            = $renew_info['dates'][0]['amount'];

$payment_info = $freeside->payment_info( array(
  'session_id' => $session_id,
) );

extract($payment_info);

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML>
  <HEAD>
    <TITLE>Renew Early</TITLE>
  </HEAD>
  <BODY>
    <H1>Renew Early</H1>

    <FONT SIZE="+1" COLOR="#ff0000"><?php echo htmlspecialchars($_GET['error']); ?></FONT>

      <FORM NAME="OneTrueForm" METHOD="POST" ACTION="process_payment_order_renew.php" onSubmit="document.OneTrueForm.process.disabled=true">

      <INPUT TYPE="hidden" NAME="date"       VALUE="<?php echo $date; ?>">
      <INPUT TYPE="hidden" NAME="session_id" VALUE="<?php echo $session_id; ?>">
      <INPUT TYPE="hidden" NAME="amount"     VALUE="<?php echo $amount; ?>">

      A payment of $<?php echo $amount; ?> will renew your account through <?php echo $renew_date_pretty; ?>.<BR><BR>

      <TABLE BGCOLOR="#cccccc">
      <TR>
        <TD ALIGN="right">Amount</TD>
        <TD>
          <TABLE><TR><TD BGCOLOR="#ffffff">
            $<?php echo $amount; ?>
          </TD></TR></TABLE>
        </TD>
      </TR>
      <TR>
        <TD ALIGN="right">Card&nbsp;type</TD>
        <TD>
          <SELECT NAME="card_type"><OPTION></OPTION>
            <?php foreach ( array_keys($card_types) as $t ) { ?>
              <OPTION <?php if ($card_type == $card_types[$t] ) { ?> SELECTED <?php } ?>
                      VALUE="<?php echo $card_types[$t]; ?>"
              ><?php echo $t; ?>
            <?php } ?>
          </SELECT>
        </TD>
      </TR>

      <TR>
        <TD ALIGN="right">Card&nbsp;number</TD>
        <TD>
          <TABLE>
            <TR>
              <TD>
                <INPUT TYPE="text" NAME="payinfo" SIZE=20 MAXLENGTH=19 VALUE="<?php echo $payinfo; ?>"> </TD>
              <TD>Exp.</TD>
              <TD>
                <SELECT NAME="month">
                  <?php foreach ( array('01','02','03','04','05','06','07','08','09','10','11','12') as $m) { ?>
                    <OPTION<?php if ($m == $month ) { ?> SELECTED<?php } ?>
                    ><?php echo $m; ?>
                  <?php } ?>
                </SELECT>
              </TD>
              <TD> / </TD>
              <TD>
                <SELECT NAME="year">
                  <?php $lt = localtime(); $y = $lt[5] + 1900;
                        for ($y = $lt[5]+1900; $y < $lt[5] + 1910; $y++ ) { ?>
                    <OPTION<?php if ($y == $year ) { ?> SELECTED<?php } ?>
                    ><?php echo $y; ?>
                  <?php } ?>
                </SELECT>
              </TD>
            </TR>
          </TABLE>
        </TD>
      </TR>
      <?php if ( $withcvv ) { ?>
        <TR>
          <TD ALIGN="right">CVV2&nbsp;(<A HREF="javascript:myopen('cvv2.html','cvv2','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=480,height=288')">help</A>)</TD>
          <TD><INPUT TYPE="text" NAME="paycvv" VALUE="" SIZE=4 MAXLENGTH=4></TD>
        </TR>
      <?php } ?>
      <TR>
        <TD ALIGN="right">Exact&nbsp;name&nbsp;on&nbsp;card</TD>
        <TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<?php echo $payname; ?>"></TD>
      </TR><TR>
        <TD ALIGN="right">Card&nbsp;billing&nbsp;address</TD>
        <TD>
          <INPUT TYPE="text" SIZE=40 MAXLENGTH=80 NAME="address1" VALUE="<?php echo $address1; ?>">
        </TD>
      </TR><TR>
        <TD ALIGN="right">Address&nbsp;line&nbsp;2</TD>
        <TD>
          <INPUT TYPE="text" SIZE=40 MAXLENGTH=80 NAME="address2" VALUE="<?php echo $address2; ?>">
        </TD>
      </TR><TR>
        <TD ALIGN="right">City</TD>
        <TD>
          <TABLE>
            <TR>
              <TD>
                <INPUT TYPE="text" NAME="city" SIZE="12" MAXLENGTH=80 VALUE="<?php echo $city; ?>">
              </TD>
              <TD>State</TD>
              <TD>
                <SELECT NAME="state">
                  <?php foreach ( $states as $s ) { ?>
                    <OPTION<?php if ($s == $state) { ?> SELECTED<?php } ?>
                    ><?php echo $s; ?>
                  <?php } ?>
                </SELECT>
              </TD>
              <TD>Zip</TD>
              <TD>
                <INPUT TYPE="text" NAME="zip" SIZE=11 MAXLENGTH=10 VALUE="<?php echo $zip; ?>">
              </TD>
            </TR>
          </TABLE>
        </TD>
      </TR>

      <TR>
        <TD COLSPAN=2>
          <INPUT TYPE="checkbox" CHECKED NAME="save" VALUE="1">
          Remember this information
        </TD>
      </TR><TR>
        <TD COLSPAN=2>
          <INPUT TYPE="checkbox"<?php if ( $payby == 'CARD' ) { ?> CHECKED<?php } ?> NAME="auto" VALUE="1" onClick="if (this.checked) { document.OneTrueForm.save.checked=true; }">
          Charge future payments to this card automatically
        </TD>
      </TR>
      </TABLE>
      <BR>
      <INPUT TYPE="hidden" NAME="paybatch" VALUE="<?php echo $paybatch; ?>">
      <INPUT TYPE="submit" NAME="process" VALUE="Process payment"> <!-- onClick="this.disabled=true"> -->
      </FORM>

  </BODY>
</HTML>
