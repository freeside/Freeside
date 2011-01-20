%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(3). 'misc/order_pkg.html?'. $cgi->query_string ) %>
%} else {
%  my $frag = "cust_pkg". $cust_pkg->pkgnum;
%  my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
%               ? ''
%               : ';show=packages';
%  my $redir_url = popurl(3)
%            ."view/cust_main.cgi?custnum=$custnum$show;fragment=$frag#$frag";
% 
% # for going right to a provision service after ordering a package
% if ( $svcpart ) { 
%    my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
%    if ( $part_svc ) {
%	$redir_url = popurl(3)."edit/".$part_svc->svcdb.".cgi?"
%		    ."pkgnum=".$cust_pkg->pkgnum.";svcpart=$svcpart";
%   }
% }
<% header('Package ordered') %>
  <SCRIPT TYPE="text/javascript">
    // XXX fancy ajax rebuild table at some point, but a page reload will do for now

    // XXX chop off trailing #target and replace... ?
    window.top.location = '<% $redir_url %>';

  </SCRIPT>

  </BODY></HTML>
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Order customer package');

#untaint custnum (probably not necessary, searching for it is escape enough)
$cgi->param('custnum') =~ /^(\d+)$/
  or die 'illegal custnum '. $cgi->param('custnum');
my $custnum = $1;
my $cust_main = qsearchs({
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die 'unknown custnum' unless $cust_main;

#probably not necessary, taken care of by cust_pkg::check
$cgi->param('pkgpart') =~ /^(\d+)$/
  or die 'illegal pkgpart '. $cgi->param('pkgpart');
my $pkgpart = $1;
$cgi->param('refnum') =~ /^(\d*)$/
  or die 'illegal refnum '. $cgi->param('refnum');
my $refnum = $1;
$cgi->param('locationnum') =~ /^(\-?\d*)$/
  or die 'illegal locationnum '. $cgi->param('locationnum');
my $locationnum = $1;
$cgi->param('discountnum') =~ /^(\-?\d*)$/
  or die 'illegal discountnum '. $cgi->param('discountnum');
my $discountnum = $1;

# for going right to a provision service after ordering a package
my $svcpart;
if ( $cgi->param('svcpart') ) {
    $cgi->param('svcpart') =~ /^(\-?\d*)$/
       or die 'illegal svcpart '. $cgi->param('svcpart');
    $svcpart = $1;
}

my $cust_pkg = new FS::cust_pkg {
  'custnum'              => $custnum,
  'pkgpart'              => $pkgpart,
  'start_date'           => ( scalar($cgi->param('start_date'))
                                ? parse_datetime($cgi->param('start_date'))
                                : ''
                            ),
  'no_auto'              => scalar($cgi->param('no_auto')),
  'refnum'               => $refnum,
  'locationnum'          => $locationnum,
  'discountnum'          => $discountnum,
  #for the create a new discount case
  'discountnum__type'    => scalar($cgi->param('discountnum__type')),
  'discountnum_amount'   => scalar($cgi->param('discountnum_amount')),
  'discountnum_percent'  => scalar($cgi->param('discountnum_percent')),
  'discountnum_months'   => scalar($cgi->param('discountnum_months')),
  'contract_end'         => ( scalar($cgi->param('contract_end'))
                                ? parse_datetime($cgi->param('contract_end'))
                                : ''
                            ),
  #'discountnum_disabled' => scalar($cgi->param('discountnum_disabled')),
};

my %opt = ( 'cust_pkg' => $cust_pkg );

if ( $locationnum == -1 ) {
  my $cust_location = new FS::cust_location {
    map { $_ => scalar($cgi->param($_)) }
        qw( custnum address1 address2 city county state zip country geocode )
  };
  $opt{'cust_location'} = $cust_location;
}

my $error = $cust_main->order_pkg( \%opt );

</%init>
