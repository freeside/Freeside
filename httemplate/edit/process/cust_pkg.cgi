% if ($error) {
%   $cgi->param('error', $error);
%   $cgi->redirect(popurl(3). $error_redirect. '?'. $cgi->query_string );
% } elsif ( $action eq 'change' ) {

    <% header("Package changed") %>
      <SCRIPT TYPE="text/javascript">
        window.top.location.reload();
      </SCRIPT>
    </BODY>
    </HTML>

% } elsif ( $action eq 'bulk' ) {
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum") %>
% } else {
%   die "guru exception #5: action is neither change nor bulk!";
% }
<%init>

my $error = '';

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/;
my $custnum = $1;

my @remove_pkgnums = map {
  /^(\d+)$/ or die "Illegal remove_pkg value!";
  $1;
} $cgi->param('remove_pkg');

my $curuser = $FS::CurrentUser::CurrentUser;

my( $action, $error_redirect );
my @pkgparts = ();
if ( $cgi->param('new_pkgpart') =~ /^(\d+)$/ ) { #came from misc/change_pkg.cgi

  $action = 'change';
  $error_redirect = "misc/change_pkg.cgi";
  @pkgparts = ($1);

  die "access denied"
    unless $curuser->access_right('Change customer package');

} else { #came from edit/cust_pkg.cgi

  $action = 'bulk';
  $error_redirect = "edit/cust_pkg.cgi";

  die "access denied"
    unless $curuser->access_right('Bulk change customer packages');

  foreach my $pkgpart ( map /^pkg(\d+)$/ ? $1 : (), $cgi->param ) {
    if ( $cgi->param("pkg$pkgpart") =~ /^(\d+)$/ ) {
      my $num_pkgs = $1;
      while ( $num_pkgs-- ) {
        push @pkgparts,$pkgpart;
      }
    } else {
      $error = "Illegal quantity";
      last;
    }
  }

}

$error ||= FS::cust_pkg::order($custnum,\@pkgparts,\@remove_pkgnums);

</%init>
