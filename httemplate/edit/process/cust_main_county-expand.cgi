<%
# <!-- $Id: cust_main_county-expand.cgi,v 1.2 2001-08-17 11:05:31 ivan Exp $ -->

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

$cgi->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum!";
$taxnum = $1;
$cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die ("Unknown taxnum!");

if ( $cgi->param('delim') eq 'n' ) {
  @expansion=split(/\n/,$cgi->param('expansion'));
} elsif ( $cgi->param('delim') eq 's' ) {
  @expansion=split(' ',$cgi->param('expansion'));
} else {
  die "Illegal delim!";
}

@expansion=map {
  unless ( /^\s*([\w\- ]+)\s*$/ ) {
    $cgi->param('error', "Illegal item in expansion");
    print $cgi->redirect(popurl(2). "cust_main_county-expand.cgi?". $cgi->query_string );
    exit;
  }
  $1;
} @expansion;

foreach ( @expansion) {
  my(%hash)=$cust_main_county->hash;
  my($new)=new FS::cust_main_county \%hash;
  $new->setfield('taxnum','');
  if ( ! $cust_main_county->state ) {
    $new->setfield('state',$_);
  } else {
    $new->setfield('county',$_);
  }
  #if (datasrc =~ m/Pg/)
  #{
  #    $new->setfield('tax',0.0);
  #}
  my($error)=$new->insert;
  die $error if $error;
}

unless ( qsearch('cust_main',{
  'state'  => $cust_main_county->getfield('state'),
  'county' => $cust_main_county->getfield('county'),
  'country' =>  $cust_main_county->getfield('country'),
} ) ) {
  my($error)=($cust_main_county->delete);
  die $error if $error;
}

print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");

%>
