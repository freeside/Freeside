#!/usr/bin/perl -Tw
#
# process/agent.cgi: Edit cust_main_county (process form)
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::cust_main_county;
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

foreach ( $req->params ) {
  /^tax(\d+)$/ or die "Illegal form $_!";
  my($taxnum)=$1;
  my($old)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
    or die "Couldn't find taxnum $taxnum!";
  next unless $old->getfield('tax') ne $req->param("tax$taxnum");
  my(%hash)=$old->hash;
  $hash{tax}=$req->param("tax$taxnum");
  my($new)=create FS::cust_main_county \%hash;
  my($error)=$new->replace($old);
  eidiot($error) if $error;
}

$req->cgi->redirect("../../browse/cust_main_county.cgi");

