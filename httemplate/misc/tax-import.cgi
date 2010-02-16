<% include("/elements/header.html",'Batch Tax Rate Import') %>

Import a CSV file set containing tax rate records.
<BR><BR>

<% include( '/elements/form-file_upload.html',
              'name'      => 'TaxRateUpload',
              'action'    => 'process/tax-import.cgi', 
              'num_files' => 6,
              'fields'    => [ 'format', 'reload' ],
              'message'   => 'Tax rates imported',
          )
%>

<% &ntable("#cccccc", 2) %>

  <TR>
    <TH ALIGN="right">Format</TH>
    <TD>
      <SELECT NAME="format">
        <!-- <OPTION VALUE="cch-update" SELECTED>CCH update (CSV) -->
        <OPTION VALUE="cch">CCH import (CSV)
        <!-- <OPTION VALUE="cch-fixed-update">CCH update (fixed length) -->
        <OPTION VALUE="cch-fixed">CCH import (fixed length)
      </SELECT>
    </TD>
  </TR>

  <TR>
    <TH ALIGN="right">Replace existing data from this vendor</TH>
    <TD>
      <INPUT NAME="reload" TYPE="checkbox" VALUE="1" CHECKED>
    </TD>
  </TR>

  <% include( '/elements/file-upload.html',
                'field'    => [ 'geofile',
                                'codefile',
                                'plus4file',
                                'zipfile',
                                'txmatrix',
                                'detail',
                              ],
                'label'    => [ 'geocode filename',
                                'code filename',
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
