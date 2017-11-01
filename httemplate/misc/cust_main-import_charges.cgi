<% include("/elements/header.html",'Batch Charge Import') %>

Import a CSV file containing customer charges.
<BR><BR>

<& /elements/form-file_upload.html,
     'name'      => 'OneTimeChargeImportForm',
     'action'    => 'process/cust_main-import_charges.cgi',
     'num_files' => 1,
     'fields'    => [ 'agentnum', 'custbatch', 'format' ],
     'message'   => 'One time charge batch import successful',
     'url'       => $p."misc/cust_main-import_charges.cgi",
     'onsubmit'  => "document.OneTimeChargeImportForm.submitButton.disabled=true;",
&>

<% &ntable("#cccccc", 2) %>

<% include('/elements/tr-select-agent.html',
              #'curr_value' => '', #$agentnum,
              'label'       => "<B>Agent</B>",
              'empty_label' => 'Select agent',
           )
%>

<INPUT TYPE="hidden" NAME="custbatch" VALUE="<% $custbatch %>"%>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="simple">Simple
      <OPTION VALUE="ooma">Ooma
<!--      <OPTION VALUE="extended" SELECTED>Extended -->
    </SELECT>
  </TD>
</TR>

  <% include( '/elements/file-upload.html',
                'field' => 'file',
                'label' => 'Filename',
            )
  %>

<TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE    = "submit"
             NAME    = "submitButton"
             ID      = "submitButton"
             VALUE   = "Import file"
      >
    </TD>
</TR>

</TABLE>

</FORM>

<BR>

Simple file format is CSV, with the following field order: <i>custnum, agent_custid, amount, description</i>
<BR><BR>

<!-- Extended file format is not yet defined</i>
<BR><BR> -->

Field information:

<ul>

  <li><i>custnum</i>: This is the freeside customer number.  It may be left blank.  If specified, agent_custid must be blank.

  <li><i>agent_custid</i>: This is the reseller's idea of the customer number or identifier.  It may be left blank.  If specified, custnum must be blank.

  <li><i>amount</i>: A numeric value with at most two digits after the decimal point.  If <i>amount</i> is negative, a credit will be applied instead.

  <li><i>description</i>: Text describing the transaction.

</ul>

<BR>

<b>Ooma</b> format has the following field order: <i>Description, Description2, Record Type, Customer Number, Billing Phone Number or Zip Code, Bus/Res Indicator, Invoice Date, Invoice Number, Group, Item, Revenue<%$req%>, LineCount, Exempt, ExemptList, State, City, Zipcode, OfferingPK, Offering name<%$req%>, Quantity, AccountNo<%$req%>, Status, Cust Created, PartnerID</i>
<BR><BR>


<% include('/elements/footer.html') %>

<%once>
  my $req = qq!<font color="#ff0000">*</font>!;
</%once>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

  my $custbatch = time2str('webimport-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);

</%init>

