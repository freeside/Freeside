#!/usr/bin/perl -Tw
#
# $Id: svc_acct_pop.cgi,v 1.3 1998-12-30 23:03:32 ivan Exp $
#
# ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: svc_acct_pop.cgi,v $
# Revision 1.3  1998-12-30 23:03:32  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.2  1998/12/17 08:40:28  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct_pop;
use FS::CGI qw(popurl eidiot);

my($cgi)=new CGI; # create form object

&cgisuidsetup($cgi);

my($popnum)=$cgi->param('popnum');

my($old)=qsearchs('svc_acct_pop',{'popnum'=>$popnum}) if $popnum;

my($new)=create FS::svc_acct_pop ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('svc_acct_pop')
} );

if ( $popnum ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $popnum=$new->getfield('popnum');
}
print $cgi->redirect(popurl(3). "browse/svc_acct_pop.cgi");

