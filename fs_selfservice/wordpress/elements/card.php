<TR>
  <TD ALIGN="right">Card&nbsp;number</TD>
  <TD COLSPAN=6>
    <TABLE>
      <TR>
        <TD>
          <INPUT TYPE="text" NAME="payinfo" SIZE=20 MAXLENGTH=19 VALUE="<?php echo $payinfo ?>"> </TD>
        <TD>Exp.</TD>
        <TD>
          <SELECT NAME="month">
            <?php $months = array( '01', '02', '03' ,'04', '05', '06', '07', '08', '09', '10', '11', '12' );
               foreach ( $months AS $m ) {
            ?>
                 <OPTION <?php if ($m == $month) { echo 'SELECTED'; } ?>><?php echo $m; ?>
            <?php } ?>
          </SELECT>
        </TD>
        <TD> / </TD>
        <TD>
          <SELECT NAME="year">
            <?php $years = array( '2015', '2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023' );
               foreach ( $years as $y ) {
            ?>
                  <OPTION <?php if ($y == $year ) { echo 'SELECTED'; } ?>><?php echo $y; ?>
            <?php } ?>
          </SELECT>
        </TD>
      </TR>
    </TABLE>
  </TD>
</TR>
<?php  if ( $withcvv ) { ?>
  <TR>
    <TD ALIGN="right">CVV2&nbsp;(<A HREF="javascript:myopen('cvv2.html','cvv2','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=480,height=288')">help</A>)</TD>
    <TD><INPUT TYPE="text" NAME="paycvv" VALUE="" SIZE=4 MAXLENGTH=4></TD>
  </TR>
<?php } ?>
<TR>
  <TD ALIGN="right">Exact&nbsp;name&nbsp;on&nbsp;card</TD>
  <TD COLSPAN=6><INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<?php echo $payname; ?>"></TD>
</TR>

<?php $lf = $freeside->mason_comp(array(
           'session_id'     => $_COOKIE['freeside_session_id'],
           'comp'       => '/elements/location.html',
           'args'       => [
                             'no_asterisks'   , 1,
                             #'address1_label' , 'Card billing address',
                             'address1_label' , 'Card&nbsp;billing&nbsp;address',
                           ],
         ));
   echo $lf['output'];
?>
