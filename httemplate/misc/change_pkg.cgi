<% include('/elements/header.html', "Change Package") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<% small_custview( $cust_main, $conf->config('countrydefault') || '' , '', 
                      "${p}view/cust_main.cgi")
%>

<FORM ACTION="<% $p %>edit/process/cust_pkg.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="remove_pkg" VALUE="<% $pkgnum %>">

<BR>
Current package: <% $part_pkg->pkg %> - <% $part_pkg->comment %>

<BR>
New package: <SELECT NAME="new_pkgpart"><OPTION VALUE=0></OPTION>

%foreach my $part_pkg (
%  grep { ! $_->disabled && $_->pkgpart != $cust_pkg->pkgpart }
%    map { $_->part_pkg } $agent->agent_type->type_pkgs
%) {
%  my $pkgpart = $part_pkg->pkgpart;

  <OPTION VALUE="<% $pkgpart %>" <% ( $cgi->param('error') && $cgi->param('new_pkgpart') == $pkgpart ) ? ' SELECTED' : '' %>>
    <% $pkgpart %>: <% $part_pkg->pkg %> - <% $part_pkg->comment %>
  </OPTION>

%}

</SELECT>
<BR><BR><INPUT TYPE="submit" VALUE="Change package">
    </FORM>
  </BODY>
</HTML>
<%init>

my $pkgnum;
if ( $cgi->param('error') ) {
  #$custnum = $cgi->param('custnum');
  #%remove_pkg = map { $_ => 1 } $cgi->param('remove_pkg');
  $pkgnum = ($cgi->param('remove_pkg'))[0];
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  #$custnum = $1;
  $pkgnum = $1;
  #%remove_pkg = ();
}

my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } )
  or die "unknown pkgnum $pkgnum";
my $custnum = $cust_pkg->custnum;

my $conf = new FS::Conf;

my $p1 = popurl(1);

my $cust_main = $cust_pkg->cust_main
  or die "can't get cust_main record for custnum ". $cust_pkg->custnum.
         " ( pkgnum ". cust_pkg->pkgnum. ")";
my $agent = $cust_main->agent;

my $part_pkg = $cust_pkg->part_pkg;

</%init>
