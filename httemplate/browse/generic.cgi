<%

use FS::Record qw(qsearch dbdef);
use DBIx::DBSchema;
use DBIx::DBSchema::Table;

my $error;
my $p2 = popurl(2);
my ($table) = $cgi->keywords;
my $dbdef = dbdef or die "Cannot fetch dbdef!";
my $dbdef_table = $dbdef->table($table) or die "Cannot fetch schema for $table";

my $pkey = $dbdef_table->primary_key or die "Cannot fetch pkey for $table";
print header("Browse $table", menubar('Main Menu'   => $p));

my @rec = qsearch($table, {});
my @col = $dbdef_table->columns;

if ($cgi->param('error')) { %>
   <FONT SIZE="+1" COLOR="#ff0000">Error: <%=$cgi->param('error')%></FONT>
   <BR><BR>
<% } 
%>
<A HREF="<%=$p2%>edit/<%=$table%>.cgi"><I>Add a new <%=$table%></I></A><BR><BR>

<%=table()%>
<TH>
<% foreach (grep { $_ ne $pkey } @col) {
  %><TD><%=$_%></TD>
  <% } %>
</TH>
<% foreach $rec (sort {$a->getfield($pkey) cmp $b->getfield($pkey) } @rec) { 
  %>
  <TR>
    <TD>
      <A HREF="<%=$p2%>edit/<%=$table%>.cgi?<%=$rec->getfield($pkey)%>">
      <%=$rec->getfield($pkey)%></A> </TD> <%
  foreach $col (grep { $_ ne $pkey } @col)  { %>
    <TD><%=$rec->getfield($col)%></TD> <% } %>
  </A>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>

