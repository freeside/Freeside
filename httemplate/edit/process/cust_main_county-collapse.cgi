<%
# <!-- $Id: cust_main_county-collapse.cgi,v 1.1 2001-08-17 11:05:31 ivan Exp $ -->

use strict;
use vars qw ( $cgi $taxnum $cust_main_county @expansion $expansion );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup datasrc);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(popurl);
use FS::cust_main_county;
use FS::cust_main;

$cgi = new CGI;
&cgisuidsetup($cgi);

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/ or die "Illegal taxnum!";
$taxnum = $1;
$cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
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
