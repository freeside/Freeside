#!/usr/bin/perl -Tw
#
# $Id: part_svc.cgi,v 1.7 1999-02-07 09:59:29 ivan Exp $
#
# ivan@sisd.com 97-nov-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_svc.cgi,v $
# Revision 1.7  1999-02-07 09:59:29  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.6  1999/01/19 05:13:57  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 22:47:58  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.4  1998/12/30 23:03:31  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.3  1998/12/17 08:40:26  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/21 06:43:08  ivan
# s/CGI::Request/CGI.pm/
#

use strict;
use vars qw ( $cgi $svcpart $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::part_svc;
use FS::CGI qw(popurl);

$cgi = new CGI;
&cgisuidsetup($cgi);

$svcpart = $cgi->param('svcpart');

$old = qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

$new = new FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } fields('part_svc')
} );

if ( $svcpart ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcpart=$new->getfield('svcpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_svc.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3)."browse/part_svc.cgi");
}

