<% include('/elements/header.html', "Mail Forward $action") %>

<% include('/elements/error.html') %>

Service #<% $svcnum ? "<B>$svcnum</B>" : " (NEW)" %><BR>
Service: <B><% $part_svc->svc %></B><BR><BR>

<FORM ACTION="process/svc_forward.cgi" METHOD="POST">

<% include('elements/svc_forward.html',
     'conf'    => $conf,
     'svcnum'  => $svcnum,
     'pkgnum'  => $pkgnum,
     'svcpart' => $svcpart,
     'srcsvc'  => $srcsvc,
     'dstsvc'  => $dstsvc,
     'src'     => $src,
     'dst'     => $dst,
     'email'   => \%email,
   ) %>

<BR><INPUT TYPE="submit" VALUE="Submit">
</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;

my($svcnum, $pkgnum, $svcpart, $part_svc, $svc_forward);
if ( $cgi->param('error') ) {
  $svc_forward = new FS::svc_forward ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_forward')
  } );
  $svcnum = $svc_forward->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_forward = new FS::svc_forward({});

  $svcnum='';

  $svc_forward->set_default_and_fixed;

} else { #editing

  my($query) = $cgi->keywords;

  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_forward=qsearchs('svc_forward',{'svcnum'=>$svcnum})
    or die "Unknown (svc_forward) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;
  
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svc_forward->svcnum ? 'Edit' : 'Add';

my %email;

if ($pkgnum) {

  #find all possible user svcnums (and emails)

  my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  die "Specified package not found" unless $cust_pkg;
  %email = $cust_pkg->forward_emails('svc_forward' => $svc_forward);

} elsif ( $action eq 'Add' ) {

  die "\$action eq Add, but \$pkgnum is null!\n";

} else {

  use FS::cust_pkg;
  %email = FS::cust_pkg->forward_emails('svc_forward' => $svc_forward);

}

my($srcsvc,$dstsvc,$dst)=(
  $svc_forward->srcsvc,
  $svc_forward->dstsvc,
  $svc_forward->dst,
);
my $src = $svc_forward->dbdef_table->column('src') ? $svc_forward->src : '';

</%init>
