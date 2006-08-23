<% include("/elements/header.html",'Batch Customer Import') %>

<FORM ACTION="process/cust_main-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">

Import a CSV file containing customer records.
<BR><BR>

<!-- Simple file format is CSV, with the following field order: <i>cust_pkg.setup, dayphone, first, last, address1, address2, city, state, zip, comments</i>
<BR><BR> -->

Extended file format is CSV, with the following field order: <i>agent_custid, refnum[1], last, first, address1, address2, city, state, zip, country, daytime, night, ship_last, ship_first, ship_address1, ship_address2, ship_city, ship_state, ship_zip, ship_country, payinfo, paycvv, paydate, invoicing_list, pkgpart, username, _password</i>
<BR><BR>

[1] This field has special treatment upon import: If a string is passed instead
of an integer, the string is searched for and if necessary auto-created in the
target table.
<BR><BR>

<% &ntable("#cccccc") %>

<% include('/elements/tr-select-agent.html', '', #$agentnum,
              'label'       => "<B>Agent</B>",
              'empty_label' => 'Select agent',
           )
%>

<TR>
  <TH ALIGN="right">Format</TH>
  <TD>
    <SELECT NAME="format">
<!--      <OPTION VALUE="simple">Simple -->
      <OPTION VALUE="extended" SELECTED>Extended
    </SELECT>
  </TD>
</TR>

<TR>
  <TH ALIGN="right">CSV filename</TH>
  <TD><INPUT TYPE="file" NAME="csvfile"></TD>
</TR>
% #include('/elements/tr-select-part_referral.html')
%


<!--
<TR>
  <TH>First package</TH>
  <TD>
    <SELECT NAME="pkgpart"><OPTION VALUE="">(none)</OPTION>
% foreach my $part_pkg ( qsearch('part_pkg',{'disabled'=>'' }) ) { 

       <OPTION VALUE="<% $part_pkg->pkgpart %>"><% $part_pkg->pkg. ' - '. $part_pkg->comment %></OPTION>
% } 

    </SELECT>
  </TD>
</TR>
-->

</TABLE>
<BR><BR>

<INPUT TYPE="submit" VALUE="Import">
</FORM>

<% include('/elements/footer.html') %>

