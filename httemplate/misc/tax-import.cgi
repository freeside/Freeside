<% include("/elements/header.html",'Batch Tax Rate Import') %>

Import a CSV file set containing tax rate records.
<BR><BR>

<FORM ACTION="process/tax-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">

<% &ntable("#cccccc", 2) %>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
      <OPTION VALUE="cch">CCH
<!--      <OPTION VALUE="extended" SELECTED>Extended
      <OPTION VALUE="extended-plus_company">Extended plus company -->
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

<BR>

<!-- Simple file format is CSV, with the following field order: <i>cust_pkg.setup, dayphone, first, last, address1, address2, city, state, zip, comments</i>
<BR><BR> -->

<%$req%> Required fields
<BR><BR>

Field information:

<ul>

  <li><i>refnum</i>: Advertising source number - where a customer heard about your service.  Configuration -&gt; Miscellaneous -&gt; View/Edit advertising sources.  This field has special treatment upon import: If a string is passed instead
of an integer, the string is searched for and if necessary auto-created in the
advertising source table.

  <li><i>payinfo</i>: Credit card number, or leave this, <i>paycvv</i> and <i>paydate</i> blank for email/paper invoicing.

  <li><i>paycvv</i>: CVV2 number (three digits on the back of the credit card)

  <li><i>paydate</i>: Credit card expiration date, MM/YYYY or MM/YY (M/YY and M/YYYY are also accepted).

  <li><i>invoicing_list</i>: Email address for invoices, or POST for postal invoices.

  <li><i>pkgpart</i>: Package definition.  Configuration -&gt; Provisioning, services and packages -&gt; View/Edit package definitions

  <li><i>username</i> and <i>_password</i> are required if <i>pkgpart</i> is specified.
</ul>

<BR>

<% include('/elements/footer.html') %>

<%once>

my $req = qq!<font color="#ff0000">*</font>!;

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
