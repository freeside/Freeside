<%
#<!-- $Id: svc_acct_pop.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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

%>
