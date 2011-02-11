<% include('/elements/header.html', { title => 'CDR Types' } ) %>
<% include('/elements/menubar.html', 'Rate plans' => "${p}browse/rate.cgi" ) %>
<BR><% include('/elements/error.html') %>
<BR>
CDR types define types of phone usage for billing, such as voice 
calls and SMS messages.  Each CDR type must have a set of rates 
configured in the rate tables.
<BR>
<FORM METHOD="POST" ACTION="<% "${p}edit/process/cdr_type.cgi" %>">
<% include('/elements/auto-table.html',
  'header' => [ 'Type#', 'Name' ],
  'fields' => [ qw( cdrtypenum cdrtypename ) ],
  'data'   => \@data,
  ) %>
<INPUT TYPE="submit" VALUE="Apply changes"> </FORM> <BR>
<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @data = (
  map { [ $_->cdrtypenum, $_->cdrtypename ] }
  qsearch({ 
    'table' => 'cdr_type',
    'hashref' => {},
    'order_by' => 'ORDER BY cdrtypenum ASC'
  })
);

</%init>
