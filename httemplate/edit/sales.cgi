<% include("/elements/header.html","$action Sales Person", menubar(
  'View all sales people' => $p. 'browse/sales.cgi',
)) %>

<% include('/elements/error.html') %>

<FORM METHOD   = POST
      ACTION   = "<%popurl(1)%>process/sales.cgi"
>

<INPUT TYPE="hidden" NAME="salesnum" VALUE="<% $sales->salesnum %>">
Sales #<% $sales->salesnum ? $sales->salesnum : "(NEW)" %>

<% &ntable("#cccccc", 2, '') %>

  <TR>
    <TH ALIGN="right">Sales</TH>
    <TD><INPUT TYPE="text" NAME="salesperson" SIZE=32 VALUE="<% $sales->salesperson %>"></TD>
  </TR>

  <TR>
    <TD ALIGN="right"><% emt('Agent') %></TD>
    <TD>
      <& /elements/select-agent.html,
                     'curr_value' => $sales->salesnum,
                     'disable_empty' => 1,
      &>
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right">Disable</TD>
    <TD><INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $sales->disabled eq 'Y' ? ' CHECKED' : '' %>></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Access Groups</TD>
    <TD><% include('/elements/checkboxes-table.html',
                     'source_obj'   => $sales,
                     'link_table'   => 'access_groupsales',
                     'target_table' => 'access_group',
                     'name_col'     => 'groupname',
                     'target_link'  => $p. 'edit/access_group.html?',
                  )
        %>
    </TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="<% $sales->salesnum ? "Apply changes" : "Add sales" %>">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $sales;
if ( $cgi->param('error') ) {
  $sales = new FS::sales ( {
    map { $_, scalar($cgi->param($_)) } fields('sales')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $sales = qsearchs( 'sales', { 'salesnum' => $1 } );
} else { #adding
  $sales = new FS::sales {};
}
my $action = $sales->salesnum ? 'Edit' : 'Add';

my $conf = new FS::Conf;

</%init>
