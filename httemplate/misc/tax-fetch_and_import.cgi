<% include("/elements/header.html",'Tax Rate Download and Import') %>

Import a tax data update.
<BR><BR>

<% include( '/elements/progress-init.html', 'TaxRateImport',[ 'format', ],
              'process/tax-fetch_and_import.cgi', { 'message' => 'Tax rates imported' },
          )
%>

<FORM NAME="TaxRateImport" ACTION="javascript:void()" METHOD="POST">
<% &ntable("#cccccc", 2) %>

  <TR>
    <TH ALIGN="right">Format</TH>
    <TD>
      <SELECT NAME="format">
        <OPTION VALUE="cch">CCH import
      </SELECT>
    </TD>
  </TR>
  <TR>
    <TH ALIGN="right">Update Password</TH>
    <TD>
      <INPUT TYPE="text" NAME="password">
    </TD>
  </TR>

  <TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE    = "submit"
             VALUE   = "Download and Import"
             onClick = "document.TaxRateImport.submit.disabled=true; process();"
      >
    </TD>
  </TR>

</TABLE>

</FORM>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
