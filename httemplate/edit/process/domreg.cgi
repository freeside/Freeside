%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

$cgi->param('op') =~ /^(register|transfer|revoke|renew)$/ or die "Illegal operation";
my $operation = $1;
#my($query) = $cgi->keywords;
#$query =~ /^(\d+)$/;
$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;
my $svc_domain = qsearchs({
  'select'    => 'svc_domain.*',
  'table'     => 'svc_domain',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => {'svcnum'=>$svcnum},
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Unknown svcnum" unless $svc_domain;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $error = '';

my @exports = $part_svc->part_export();

my $registrar;
my $export;

# Find the first export that does domain registration
foreach (@exports) {
	$export = $_ if $_->can('registrar');
}

my $period = 1; # Current OpenSRS export can only handle 1 year registrations

# If we have a domain registration export, get the registrar object
if ($export) {
	if ($operation eq 'register') {
		$error = $export->register( $svc_domain, $period );
	} elsif ($operation eq 'transfer') {
		$error = $export->transfer( $svc_domain );
	} elsif ($operation eq 'revoke') {
		$error = $export->revoke( $svc_domain );
	} elsif ($operation eq 'renew') {
		$cgi->param('period') =~ /^(\d+)$/ or die "Illegal renewal period!";
		$period = $1;
		$error = $export->renew( $svc_domain, $period );
	}
}

</%init>
