<& /elements/header.html, 'Batch Payment Import' &>

Import a file containing customer payments.
<BR><BR>


<% include( '/elements/form-file_upload.html',
     'name'      => 'OneTrueForm',
     'action'    => 'process/cust_pay-import.cgi', #progress-init target
     'fields'    => [ 'agentnum', '_date', 'paybatch', 'format', 'payby' ],
     'num_files' => 1,
     'url' => popurl(2)."search/cust_pay.html?magic=paybatch;paybatch=$paybatch",
     'message' => 'Batch Payment Imported',
   )
%>

<% &ntable("#cccccc", 2) %>

<INPUT TYPE="hidden" NAME="paybatch" VALUE="<% $paybatch | h %>">

<& /elements/tr-select-agent.html,
     'label'       => "<B>Agent</B>",
     'empty_label' => 'Select agent',
&>

<& /elements/tr-input-date-field.html, {
     'name'  => '_date',
     'label' => '<B>Date</B>',
   }
&>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="simple-csv">Comma-separated (.csv)</OPTION>
      <OPTION VALUE="simple-xls">Excel (.xls)</OPTION>
    </SELECT>
  </TD>
</TR>

<% include( '/elements/tr-select-payby.html',
     'paybys' => \%paybys,
     'disable_empty' => 1,
     'label'  => '<B>Payment type</B>',
   )
%>

<% include( '/elements/file-upload.html',
             'field'    => 'file',
             'label'    => 'Filename',
   )
%>

<TR><TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px"><INPUT TYPE="submit" VALUE="Import file"></TD></TR>

</TABLE>

</FORM>

<BR>

Simple file format is CSV or XLS, with the following field order: <i>custnum, agent_custid, amount, checknum, invnum</i>
<BR><BR>

<!-- Extended file format is not yet defined -->

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

<%init>
my $paybatch = time2str('webbatch-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);
my %paybys;
tie %paybys, 'Tie::IxHash', FS::payby->payment_payby2longname();
</%init>
