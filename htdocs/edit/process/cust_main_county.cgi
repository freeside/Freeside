#!/usr/bin/perl -Tw
#
# $Id: cust_main_county.cgi,v 1.3 1998-12-17 08:40:21 ivan Exp $
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: cust_main_county.cgi,v $
# Revision 1.3  1998-12-17 08:40:21  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/18 09:01:41  ivan
# i18n! i18n!
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(eidiot);
use FS::Record qw(qsearch qsearchs);
use FS::cust_main_county;

my($cgi)=new CGI;
&cgisuidsetup($cgi);

foreach ( $cgi->param ) {
  /^tax(\d+)$/ or die "Illegal form $_!";
  my($taxnum)=$1;
  my($old)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
    or die "Couldn't find taxnum $taxnum!";
  next unless $old->getfield('tax') ne $cgi->param("tax$taxnum");
  my(%hash)=$old->hash;
  $hash{tax}=$cgi->param("tax$taxnum");
  my($new)=create FS::cust_main_county \%hash;
  my($error)=$new->replace($old);
  eidiot($error) if $error;
}

print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");

