<!-- $Id: cust_main_county-collapse.cgi,v 1.2 2002-01-30 14:18:09 ivan Exp $ -->
<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ or die "Illegal taxnum!";
my $taxnum = $1;
my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die ("Unknown taxnum!");

#really should do this in a .pm & start transaction

foreach my $delete ( qsearch('cust_main_county', {
                    'country' => $cust_main_county->country,
                    'state' => $cust_main_county->state  
                 } ) ) {
#  unless ( qsearch('cust_main',{
#    'state'  => $cust_main_county->getfield('state'),
#    'county' => $cust_main_county->getfield('county'),
#    'country' =>  $cust_main_county->getfield('country'),
#  } ) ) {
    my $error = $delete->delete;
    die $error if $error;
#  } else {
    #should really fix the $cust_main record
#  }

}

$cust_main_county->taxnum('');
$cust_main_county->county('');
my $error = $cust_main_county->insert;
die $error if $error;

print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");

%>
