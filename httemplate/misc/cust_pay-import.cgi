<& /elements/header.html, 'Batch Payment Import' &>

Import a CSV file containing customer payments.
<BR><BR>

<FORM ACTION="process/cust_pay-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">

<% &ntable("#cccccc", 2) %>

<& /elements/tr-select-agent.html,
     #'curr_value' => '', #$agentnum,
     'label'       => "<B>Agent</B>",
     'empty_label' => 'Select agent',
&>

<& /elements/tr-input-date-field.html, {
     'name'  => '_date',
     #'value' => '',
     'label' => 'Date',
   }
&>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="simple">Simple
<!--      <OPTION VALUE="extended" SELECTED>Extended -->
    </SELECT>
  </TD>
</TR>

<TR>
  <TH ALIGN="right">CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="csvfile"></TD>
</TR>

<TR><TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px"><INPUT TYPE="submit" VALUE="Import CSV file"></TD></TR>

</TABLE>

</FORM>

<BR>

Simple file format is CSV, with the following field order: <i>custnum, agent_custid, amount, checknum</i>
<BR><BR>

<!-- Extended file format is not yet defined</i>
<BR><BR> -->

Field information:

<ul>

  <li><i>custnum</i>: This is the freeside customer number.  It may be left blank.  If specified, agent_custid must be blank.

  <li><i>agent_custid</i>: This is the reseller's idea of the customer number or identifier.  It may be left blank.  If specified, custnum must be blank.

  <li><i>amount</i>: A positive numeric value with at most two digits after the decimal point.

  <li><i>checknum</i>: A sequence of digits.  May be left blank.

  <li><i>invnum</i>: Invoice number, optional

</ul>

<BR>

<& /elements/footer.html &>
