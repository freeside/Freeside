<% include('/elements/header.html', 'Batch Customer Charge') %>

<FORM ACTION="process/cust_main-import_charges.cgi" METHOD="post" ENCTYPE="multipart/form-data">

Import a CSV file containing customer charges.<BR><BR>
Default file format is CSV, with the following field order: <i>custnum, amount, description</i><BR><BR>
If <i>amount</i> is negative, a credit will be applied instead.<BR><BR>
<BR><BR>

CSV Filename: <INPUT TYPE="file" NAME="csvfile"><BR><BR>
<INPUT TYPE="submit" VALUE="Import">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
