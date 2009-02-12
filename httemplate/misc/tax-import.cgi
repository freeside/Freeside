<% include("/elements/header.html",'Batch Tax Rate Import') %>

Import a CSV file set containing tax rate records.
<BR><BR>

<% include( '/elements/form-file_upload.html',
              'name'      => 'TaxRateUpload',
              'action'    => 'process/tax-import.cgi', 
              'num_files' => 5,
              'fields'    => [ 'format', ],
              'message'   => 'Tax rates imported',
          )
%>

<% &ntable("#cccccc", 2) %>

  <TR>
    <TH ALIGN="right">Format</TH>
    <TD>
      <SELECT NAME="format">
        <OPTION VALUE="cch-update" SELECTED>CCH update (CSV)
        <OPTION VALUE="cch">CCH initial import (CSV)
        <OPTION VALUE="cch-fixed-update">CCH update (fixed length)
        <OPTION VALUE="cch-fixed">CCH initial import (fixed length)
      </SELECT>
    </TD>
  </TR>

  <% include( '/elements/file-upload.html',
                'field'    => [ 'codefile',
                                'plus4file',
                                'zipfile',
                                'txmatrix',
                                'detail',
                              ],
                'label'    => [ 'code filename',
                                'plus4 filename',
                                'zip filename',
                                'txmatrix filename',
                                'detail filename',
                              ],
                'debug'    => 0,
            )
  %>

  <TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE    = "submit"
             VALUE   = "Import CSV files"
             onClick = "document.TaxRateUpload.submit.disabled=true;"
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
