<%
#<!-- $Id: cust_main_county.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearch qsearchs);
use FS::cust_main_county;

$cgi = new CGI;
&cgisuidsetup($cgi);

foreach ( $cgi->param ) {
  /^tax(\d+)$/ or die "Illegal form $_!";
  my($taxnum)=$1;
  my($old)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
    or die "Couldn't find taxnum $taxnum!";
  next unless $old->getfield('tax') ne $cgi->param("tax$taxnum");
  my(%hash)=$old->hash;
  $hash{tax}=$cgi->param("tax$taxnum");
  my($new)=new FS::cust_main_county \%hash;
  my($error)=$new->replace($old);
  if ( $error ) {
    $cgi->param('error', $error);
    print $cgi->redirect(popurl(2). "cust_main_county.cgi?". $cgi->query_string );
    exit;
  }
}

print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");

%>
