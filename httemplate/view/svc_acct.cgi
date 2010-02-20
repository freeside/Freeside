% if ( $custnum ) { 

  <% include("/elements/header.html","View $svc account") %>
  <% include( '/elements/small_custview.html', $custnum, '', 1,
     "${p}view/cust_main.cgi") %>
  <BR>

% } else { 

  <SCRIPT>
  function areyousure(href) {
      if (confirm("Permanently delete this account?") == true)
          window.location.href = href;
  }
  </SCRIPT>
  
  <% include("/elements/header.html",'View account', menubar(
    "Cancel this (unaudited) account" =>
            "javascript:areyousure(\'${p}misc/cancel-unaudited.cgi?$svcnum\')",
  )) %>

% } 

<% include( 'svc_acct/radius_usage.html',
              'svc_acct' => $svc_acct,
              'part_svc' => $part_svc,
              'cust_pkg' => $cust_pkg,
              %gopt,
          )
%>

<% include( 'svc_acct/change_svc_form.html',
              'part_svc' => \@part_svc,
              'svcnum'   => $svcnum,
              'pkgnum'   => $pkgnum,
              %gopt,
          )
%>

Service #<B><% $svcnum %></B>
| <A HREF="<%$p%>edit/svc_acct.cgi?<%$svcnum%>">Edit this service</A>

<% include( 'svc_acct/change_svc.html',
              'part_svc' => \@part_svc,
              %gopt,
          )
%>

<% include( 'svc_acct/basics.html',
              'svc_acct' => $svc_acct,
              'part_svc' => $part_svc,
              %gopt,
          )
%>

</FORM>
<BR>

<% include( 'svc_acct/hosting.html',
              %gopt,
          )
%>

%#remove this?  does anybody even use it?  it was a misunderstood customer
%#request IIRC?
% my $conf = new FS::Conf;
% if ( $conf->exists('svc_acct-notes') ) {
%   warn 'WARNING: svc_acct-notes deprecated\n';
<% join("<BR>", $conf->config('svc_acct-notes') ) %>
<BR><BR>
% }

<% include('elements/svc_export_settings.html', $svc_acct) %>

<% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_acct = qsearchs({
  'select'    => 'svc_acct.*',
  'table'     => 'svc_acct',
  'addl_from' => $addl_from,
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
});
die "Unknown svcnum" unless $svc_acct;

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc' , { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;
my $svc = $part_svc->svc;

my @part_svc = ();
if ($FS::CurrentUser::CurrentUser->access_right('Change customer service')) {

  if ( $pkgnum ) { 
    @part_svc = grep {    $_->svcdb   eq 'svc_acct'
                       && $_->svcpart != $part_svc->svcpart }
                $cust_pkg->available_part_svc;
  } else {
    @part_svc = qsearch('part_svc', {
      svcdb    => 'svc_acct',
      disabled => '',
      svcpart  => { op=>'!=', value=>$part_svc->svcpart },
    } );
  }

}

my $communigate = scalar($part_svc->part_export('communigate_pro'));
                # || scalar($part_svc->part_export('communigate_pro_singledomain'));

my %gopt = ( 'communigate' => $communigate,
           );

</%init>
