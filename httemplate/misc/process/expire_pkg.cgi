<%

#untaint date & pkgnum

my $date;
if ( $cgi->param('date') ) {
  str2time($cgi->param('date')) =~ /^(\d+)$/ or die "Illegal date";
  $date=$1;
} else {
  $date='';
}

$cgi->param('pkgnum') =~ /^(\d+)$/ or die "Illegal pkgnum";
my $pkgnum = $1;

my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
my %hash = $cust_pkg->hash;
$hash{expire}=$date;
my $new = new FS::cust_pkg ( \%hash );
my $error = $new->replace($cust_pkg);
&eidiot($error) if $error;

print $cgi->redirect(popurl(3). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

%>
