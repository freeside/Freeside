<% include('/elements/header-popup.html', "Change Package") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>edit/process/cust_pkg.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="remove_pkg" VALUE="<% $pkgnum %>">

<% ntable('#cccccc') %>

  <TR>
    <TD>Current package:&nbsp;</TD>
    <TD>
      <B><% $part_pkg->pkgpart %>: <% $part_pkg->pkg %> - <% $part_pkg->comment %></B>
    </TD>
  </TR>
  
  <TR>
    <TD>New package: </TD>
    <TD><% include('/elements/select-cust-part_pkg.html',
                     'cust_main'    => $cust_main,
                     'element_name' => 'new_pkgpart',
                     'extra_sql'    => ' AND pkgpart != '. $cust_pkg->pkgpart,
                     'curr_value'   => ( $cgi->param('error')
                                           ? scalar($cgi->param('new_pkgpart'))
                                           : ''
                                       ),
                  )
        %>
    </TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Change package">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Change customer package');

my $pkgnum;
if ( $cgi->param('error') ) {
  $pkgnum = ($cgi->param('remove_pkg'))[0];
} else {
  $pkgnum = $cgi->param('pkgnum');
}
$pkgnum =~ /^(\d+)$/ or die "illegal pkgnum $pkgnum";
$pkgnum = $1;

my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } )
  or die "unknown pkgnum $pkgnum";
my $custnum = $cust_pkg->custnum;

my $conf = new FS::Conf;

my $cust_main = $cust_pkg->cust_main
  or die "can't get cust_main record for custnum ". $cust_pkg->custnum.
         " ( pkgnum ". cust_pkg->pkgnum. ")";
my $agent = $cust_main->agent;

my $part_pkg = $cust_pkg->part_pkg;

</%init>
