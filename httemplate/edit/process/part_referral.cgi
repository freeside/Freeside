<%
#
# $Id: part_referral.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@sisd.com 98-feb-23
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_referral.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.6  1999/02/07 09:59:28  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.5  1999/01/19 05:13:56  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 22:47:57  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.3  1998/12/30 23:03:30  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.2  1998/12/17 08:40:25  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $refnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::part_referral;
use FS::CGI qw(popurl);

$cgi = new CGI;
&cgisuidsetup($cgi);

$refnum = $cgi->param('refnum');

$new = new FS::part_referral ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_referral')
} );

if ( $refnum ) {
  my $old = qsearchs( 'part_referral', { 'refnum' =>$ refnum } );
  die "(Old) Record not found!" unless $old;
  $error = $new->replace($old);
} else {
  $error = $new->insert;
}
$refnum=$new->refnum;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_referral.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "browse/part_referral.cgi");
}

%>
