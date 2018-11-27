% if ($error) {
%   $cgi->param('error', $error);
%   $cgi->redirect(popurl(3). 'edit/cust_pkg.cgi?'. $cgi->query_string );
% } else {
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum") %>
% }
<%init>
use Data::Dumper;
my $DEBUG = 0;
my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Bulk change customer packages');

my $error = '';
my %param = $cgi->Vars;

my $custnum = $param{custnum};
$error = "Invalid custnum ($custnum)" if $custnum =~ /\D/;

my $locationnum = $param{locationnum};
$error = "Invalid locationnum ($locationnum)" if $locationnum =~ /\D/;

my @remove_pkgnum =
  map { $_ =~ /remove_cust_pkg\[(\d+)\]/ ? $1 : () }
  keys %param;

my @pkgparts;
for my $k ( keys %param ) {
  next unless $k =~ /qty_part_pkg\[(\d+)\]/;
  my $pkgpart = $1;
  my $qty     = $param{$k};
  $qty =~ s/(^\s+|\s+$)//g;

  warn "k($k) param{k}($param{$k}) pkgpart($pkgpart) qty($qty)\n"
    if $DEBUG;

  if ( $qty =~ /\D/ ) {
    $error = "Invalid quantity $qty for pkgpart $pkgpart - please use a number";
    last;
  }

  next if $qty == 0;

  push ( @pkgparts, $pkgpart ) for ( 1..$qty );
}

if ( $DEBUG ) {
  warn Dumper({
    custnum       => $custnum,
    locationnum   => $locationnum,
    remove_pkgnum => \@remove_pkgnum,
    pkgparts      => \@pkgparts,
    param         => \%param,
  });
}

$error ||= FS::cust_pkg::order({
  custnum       => $custnum,
  pkgparts      => \@pkgparts,
  remove_pkgnum => \@remove_pkgnum,
  locationnum   => $locationnum,
});

</%init>
