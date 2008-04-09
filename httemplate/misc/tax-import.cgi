<% include("/elements/header.html",'Batch Tax Rate Import') %>

Import a CSV file set containing tax rate records.
<BR><BR>

<FORM ACTION="process/tax-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">

<% &ntable("#cccccc", 2) %>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="cch" SELECTED>CCH
    </SELECT>
  </TD>
</TR>

<TR>
  <TH ALIGN="right">code CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="codefile"></TD>
</TR>

<TR>
  <TH ALIGN="right">plus4 CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="plus4file"></TD>
</TR>

<TR>
  <TH ALIGN="right">txmatrix CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="txmatrix"></TD>
</TR>

<TR>
  <TH ALIGN="right">detail CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="detail"></TD>
</TR>


<TR><TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px"><INPUT TYPE="submit" VALUE="Import CSV files"></TD></TR>

</TABLE>

</FORM>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
