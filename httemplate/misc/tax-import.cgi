<% include("/elements/header.html",'Batch Tax Rate Import') %>

Import a CSV file set containing tax rate records.
<BR><BR>

<% include( '/elements/progress-init.html',
            'TaxRateUpload',
            [ 'format', 'uploaded_files' ],
            'process/tax-import.cgi', 
            { 'message' => 'Tax rates imported' },
          )
%>

<SCRIPT>

  function gotLoaded(success, message) {

    var uploaded = document.getElementById('uploaded_files');
    var a = uploaded.value.split(',');
    if (uploaded.value.split(',').length == 4){
      process(); 
    }else{
      var p = document.getElementById('uploadError');
      p.innerHTML='<FONT SIZE="+1" COLOR="#ff0000">Error: '+message+'</FONT><BR><BR>';
      p.style='display:visible';
      return false;
    }
    
  }

</SCRIPT>

<div style="display:none:" id="uploadError"></div>
<FORM NAME="TaxRateUpload" ACTION="<% $fsurl %>misc/file-upload.html" METHOD="post" ENCTYPE="multipart/form-data" onsubmit="return doUpload(this, gotLoaded )">

<% &ntable("#cccccc", 2) %>
<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="cch-update" SELECTED>CCH update
      <OPTION VALUE="cch">CCH initial import
    </SELECT>
  </TD>
</TR>

<% include('/elements/file-upload.html', 'field'    => [ 'codefile',
                                                         'plus4file',
                                                         'txmatrix',
                                                         'detail',
                                                       ],
                                         'label'    => [ 'code CSV filename',
                                                         'plus4 CSV filename',
                                                         'txmatrix CSV filename',
                                                         'detail CSV filename',
                                                       ],
                                         'callback' => 'gotLoaded',
                                         'debug'    => 0,
   )
%>

<TR><TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px"><INPUT TYPE="submit" VALUE="Import CSV files" onClick="document.TaxRateUpload.submit.disabled=true;"></TD></TR>

</TABLE>

</FORM>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
