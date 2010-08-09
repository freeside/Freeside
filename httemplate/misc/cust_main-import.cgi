<% include("/elements/header.html",'Batch Customer Import') %>

Import a file containing customer records.
<BR><BR>

<% include( '/elements/form-file_upload.html',
              'name'      => 'CustomerImportForm',
              'action'    => 'process/cust_main-import.cgi',
              'num_files' => 1,
              'fields'    => [ 'agentnum', 'custbatch', 'format' ],
              'message'   => 'Customer import successful',
              'url'       => $p."search/cust_main.html?custbatch=$custbatch",
          )
%>

<% &ntable("#cccccc", 2) %>

  <% include( '/elements/tr-select-agent.html',
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
        <!-- <OPTION VALUE="simple">Simple -->
        <OPTION VALUE="extended" SELECTED>Extended
        <OPTION VALUE="extended-plus_company">Extended plus company
        <OPTION VALUE="svc_external">External service
        <OPTION VALUE="svc_external_svc_phone">External service and phone service
      </SELECT>
    </TD>
  </TR>

  <% include( '/elements/file-upload.html',
                'field' => 'file',
                'label' => 'Filename',
            )
  %>


% #include('/elements/tr-select-part_referral.html')
%


<!--
<TR>
  <TH>First package</TH>
  <TD>
    This needs to be agent-virtualized if it gets used!
    <SELECT NAME="pkgpart"><OPTION VALUE="">(none)</OPTION>
% foreach my $part_pkg ( qsearch('part_pkg',{'disabled'=>'' }) ) { 

       <OPTION VALUE="<% $part_pkg->pkgpart %>"><% $part_pkg->pkg_comment %></OPTION>
% } 

    </SELECT>
  </TD>
</TR>
-->

  <TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE    = "submit"
             ID      = "submit"
             VALUE   = "Import file"
             onClick = "document.CustomerImportForm.submit.disabled=true;"
      >
    </TD>
  </TR>

</TABLE>

</FORM>

<BR>

<!-- Simple file format is CSV, with the following field order: <i>cust_pkg.setup, dayphone, first, last, address1, address2, city, state, zip, comments</i>
<BR><BR> -->

Uploaded files can be CSV (comma-separated value) files or Excel spreadsheets.  The file should have a .CSV or .XLS extension.
<BR><BR>

<b>Extended</b> format has the following field order: <i>agent_custid, refnum<%$req%>, last<%$req%>, first<%$req%>, address1<%$req%>, address2, city<%$req%>, state<%$req%>, zip<%$req%>, country, daytime, night, ship_last, ship_first, ship_address1, ship_address2, ship_city, ship_state, ship_zip, ship_country, payinfo, paycvv, paydate, invoicing_list, pkgpart, username, _password</i>
<BR><BR>

<b>Extended plus company</b> format has the following field order: <i>agent_custid, refnum<%$req%>, last<%$req%>, first<%$req%>, company, address1<%$req%>, address2, city<%$req%>, state<%$req%>, zip<%$req%>, country, daytime, night, ship_last, ship_first, ship_company, ship_address1, ship_address2, ship_city, ship_state, ship_zip, ship_country, payinfo, paycvv, paydate, invoicing_list, pkgpart, username, _password</i>
<BR><BR>

<b>External service</b> format has the following field order: <i>agent_custid, refnum<%$req%>, last<%$req%>, first<%$req%>, company, address1<%$req%>, address2, city<%$req%>, state<%$req%>, zip<%$req%>, country, daytime, night, ship_last, ship_first, ship_company, ship_address1, ship_address2, ship_city, ship_state, ship_zip, ship_country, payinfo, paycvv, paydate, invoicing_list, pkgpart, next_bill_date, id, title</i>
<BR><BR>

<b>External service and phone service</b> format has the following field order: <i>agent_custid, refnum<%$req%>, last<%$req%>, first<%$req%>, company, address1<%$req%>, address2, city<%$req%>, state<%$req%>, zip<%$req%>, country, daytime, night, ship_last, ship_first, ship_company, ship_address1, ship_address2, ship_city, ship_state, ship_zip, ship_country, payinfo, paycvv, paydate, invoicing_list, pkgpart, next_bill_date, id, title, countrycode, phonenum, sip_password, pin</i>
<BR><BR>

<%$req%> Required fields
<BR><BR>

Field information:

<ul>

  <li><i>agent_custid</i>: This is the reseller's idea of the customer number or identifier.  It may be left blank.  If specified, it must be unique per-agent.

  <li><i>refnum</i>: Advertising source number - where a customer heard about your service.  Configuration -&gt; Miscellaneous -&gt; View/Edit advertising sources.  This field has special treatment upon import: If a string is passed instead
of an integer, the string is searched for and if necessary auto-created in the
advertising source table.

  <li><i>payinfo</i>: Credit card number, or leave this, <i>paycvv</i> and <i>paydate</i> blank for email/paper invoicing.

  <li><i>paycvv</i>: CVV2 number (three digits on the back of the credit card)

  <li><i>paydate</i>: Credit card expiration date, MM/YYYY or MM/YY (M/YY and M/YYYY are also accepted).

  <li><i>invoicing_list</i>: Email address for invoices, or POST for postal invoices.

  <li><i>pkgpart</i>: Package definition.  Configuration -&gt; Packages -&gt; Package definitions

  <li><i>username</i> and <i>_password</i> are required if <i>pkgpart</i> is specified. (Extended and Extended plus company formats)

  <li><i>id</i>: External service id, integer

  <li><i>title</i>: External service identifier, text

</ul>

<BR>

<% include('/elements/footer.html') %>

<%once>

my $req = qq!<font color="#ff0000">*</font>!;

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $custbatch = time2str('webimport-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);

</%init>
