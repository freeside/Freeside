<%
#<!-- $Id: part_referral.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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
