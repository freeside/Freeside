<% $cgi->redirect(popurl(1)."$svcdb.cgi?". $svcnum ) %>
<%init>

#needed here?  we're just redirecting.  i guess it could reveal the svcdb of a
#svcnum... oooooo scary.  not.
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

#some false laziness w/svc_*.cgi

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
die "Unknown svcnum" unless $cust_svc;

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $svcdb = $part_svc->svcdb;

</%init>

