#!/usr/bin/perl -Tw
#
# process/cust_main_county-expand.cgi: Expand counties (process form)
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
# Added import of datasrc from UID.pm for Pg6.3
# Default tax to 0.0 if using Pg6.3
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI
# undo default tax to 0.0 if using Pg6.3: comes from pre-expanded record
# for that state
#ivan@sisd.com 98-sep-2

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup datasrc);
use FS::Record qw(qsearch qsearchs);
use FS::cust_main_county;
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

$req->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum!";
my($taxnum)=$1;
my($cust_main_county)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die ("Unknown taxnum!");

my(@counties);
if ( $req->param('delim') eq 'n' ) {
  @counties=split(/\n/,$req->param('counties'));
} elsif ( $req->param('delim') eq 's' ) {
  @counties=split(/\s+/,$req->param('counties'));
} else {
  die "Illegal delim!";
}

@counties=map {
  /^\s*([\w\- ]+)\s*$/ or eidiot("Illegal county");
  $1;
} @counties;

my($county);
foreach ( @counties) {
  my(%hash)=$cust_main_county->hash;
  my($new)=create FS::cust_main_county \%hash;
  $new->setfield('taxnum','');
  $new->setfield('county',$_);
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
} ) ) {
  my($error)=($cust_main_county->delete);
  die $error if $error;
}

$req->cgi->redirect("../../edit/cust_main_county.cgi");

