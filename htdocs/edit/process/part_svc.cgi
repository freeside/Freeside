#!/usr/bin/perl -Tw
#
# $Id: part_svc.cgi,v 1.3 1998-12-17 08:40:26 ivan Exp $
#
# ivan@sisd.com 97-nov-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_svc.cgi,v $
# Revision 1.3  1998-12-17 08:40:26  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/21 06:43:08  ivan
# s/CGI::Request/CGI.pm/
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::part_svc qw(fields);
use FS::CGI qw(eidiot popurl);

my($cgi)=new CGI; # create form object

&cgisuidsetup($cgi);

my($svcpart)=$cgi->param('svcpart');

my($old)=qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

my($new)=create FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } fields('part_svc')
} );

if ( $svcpart ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $svcpart=$new->getfield('svcpart');
}

print $cgi->redirect(popurl(3)."browse/part_svc.cgi");

