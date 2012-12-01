<% include('/elements/header.html', { title => 'CDR Types' } ) %>
<% include('/elements/menubar.html', 'Rate plans' => "${p}browse/rate.cgi" ) %>
<BR><% include('/elements/error.html') %>
<BR>
CDR types define types of phone usage for billing, such as voice 
calls and SMS messages.  Each CDR type must have a set of rates 
configured in the rate tables.
<BR>
<FORM METHOD="POST" ACTION="<% "${p}edit/process/cdr_type.cgi" %>">
<TABLE ID="AutoTable" BORDER=0 CELLSPACING=0>
  <TR>
    <TH>Type#</TH>
    <TH>Name</TH>
  </TR>
  <TR ID="cdr_template">
    <TD>
      <INPUT NAME="cdrtypenum" SIZE=16 MAXLENGTH=16 ALIGN="right">
    </TD>
    <TD>
      <INPUT NAME="cdrtypename" SIZE=16 MAXLENGTH=16>
    </TD>
  </TR>
<&  /elements/auto-table.html,
  'template_row' => 'cdr_template',
  'data'   => \@data,
&>
</TABLE>
<INPUT TYPE="submit" VALUE="Apply changes"> </FORM> <BR>
<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @data = (
  qsearch({ 
    'table' => 'cdr_type',
    'hashref' => {},
    'order_by' => 'ORDER BY cdrtypenum ASC'
  })
);

</%init>
