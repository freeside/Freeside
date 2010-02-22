% if ( $custnum ) {

%#  <% include("/elements/header.html","View $svcdomain") %>
  <% include("/elements/header.html","View domain") %>
  <% include( '/elements/small_custview.html', $custnum, '', 1,
     "${p}view/cust_main.cgi") %>
  <BR>

% } else {

  <% include("/elements/header.html",'View domain', menubar(
       "Cancel this (unaudited) domain" =>
         "javascript:areyousure('${p}misc/cancel-unaudited.cgi?$svcnum', 'Delete $domain and all records?')",
     ))
  %>

% }

<% include('/elements/error.html') %>

<% include('svc_domain/basics.html', $svc_domain,
             'part_svc' => $part_svc,
             'custnum'  => $custnum,
          )
%>
<BR>

<% include('svc_domain/acct_defaults.html', $svc_domain,
             'part_svc' => $part_svc,
          )
%>
<BR>

<% include('svc_domain/dns.html', $svc_domain ) %>
<BR>

<% include('elements/svc_export_settings.html', $svc_domain) %>

<% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my $conf = new FS::Conf;

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_domain = qsearchs({
  'select'    => 'svc_domain.*',
  'table'     => 'svc_domain',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => {'svcnum'=>$svcnum},
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
});
die "Unknown svcnum" unless $svc_domain;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum, $display_custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs('cust_pkg', {'pkgnum'=>$pkgnum} );
  $custnum = $cust_pkg->custnum;
  $display_custnum = $cust_pkg->cust_main->display_custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $domain = $svc_domain->domain;

</%init>
