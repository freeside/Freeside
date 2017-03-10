<% $cgi->redirect($path) %>
<%init>
# since cust_pkgs can't be viewed directly, just throw a redirect
my ($pkgnum) = $cgi->keywords;
$pkgnum =~ /^\d+$/ or die "invalid pkgnum '$pkgnum'";
my $show = $FS::CurrentUser::CurrentUser->default_customer_view =~ /^(jumbo|packages)$/ ? '' : ';show=packages';

my $self = FS::cust_pkg->by_key($pkgnum) or die "pkgnum $pkgnum not found";
my $frag = 'cust_pkg'. $self->pkgnum;
my $path = $p.'view/cust_main.cgi?custnum='.$self->custnum.";$show#$frag";
</%init>
