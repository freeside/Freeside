#!/usr/bin/perl -Tw
#
# $Id: svc_acct_pop.cgi,v 1.6 1999-02-07 09:59:31 ivan Exp $
#
# ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: svc_acct_pop.cgi,v $
# Revision 1.6  1999-02-07 09:59:31  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.5  1999/01/19 05:13:59  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 22:48:00  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.3  1998/12/30 23:03:32  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.2  1998/12/17 08:40:28  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $popnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct_pop;
use FS::CGI qw(popurl);

$cgi = new CGI; # create form object

&cgisuidsetup($cgi);

$popnum = $cgi->param('popnum');

$old = qsearchs('svc_acct_pop',{'popnum'=>$popnum}) if $popnum;

$new = new FS::svc_acct_pop ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('svc_acct_pop')
} );

if ( $popnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $popnum=$new->getfield('popnum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_acct_pop.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "browse/svc_acct_pop.cgi");
}

