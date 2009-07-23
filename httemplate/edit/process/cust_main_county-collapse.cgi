<% $cgi->redirect(popurl(3). "browse/cust_main_county.cgi") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ or die "Illegal taxnum!";
my $taxnum = $1;
my $cust_main_county = qsearchs('cust_main_county', { 'taxnum' => $taxnum } )
  or die "Unknown taxnum $taxnum";

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

</%init>
