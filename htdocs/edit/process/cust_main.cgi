#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.7 1999-02-28 00:03:42 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_main.cgi
#
# ivan@voicenet.com 96-dec-04
#
# added referral check
# ivan@voicenet.com 97-jun-4
#
# rewrote for new API
# ivan@voicenet.com 97-jul-28
#
# same as above (again) and clean up some stuff ivan@sisd.com 98-feb-23
#
# Changes to allow page to work at a relative position in server
# Changed 'day' to 'daytime' because Pg6.3 reserves the day word
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_main.cgi,v $
# Revision 1.7  1999-02-28 00:03:42  ivan
# removed misleading comments
#
# Revision 1.6  1999/01/25 12:10:00  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:50  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:22:32  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.3  1998/12/17 08:40:19  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/18 08:57:36  ivan
# i18n, s/CGI-modules/CGI.pm/, FS::CGI::idiot instead of inline, FS::CGI::popurl
#

use strict;
use vars qw( $cgi $payby @invoicing_list $new $custnum $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw( popurl );
use FS::Record qw(qsearchs fields);
use FS::cust_main;

$cgi = new CGI;
&cgisuidsetup($cgi);

#unmunge stuff

$cgi->param('tax','') unless defined($cgi->param('tax'));

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

$cgi->param('state') =~ /^(\w+)( \((\w+)\))? \/ (\w+)$/;
$cgi->param('state', $1);
$cgi->param('county', $3 || '');
$cgi->param('country', $4);

if ( $payby = $cgi->param('payby') ) {
  $cgi->param('payinfo', $cgi->param( $payby. '_payinfo' ) );
  $cgi->param('paydate',
  $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' ) );
  $cgi->param('payname', $cgi->param( $payby. '_payname' ) );
}

$cgi->param('otaker', &getotaker );

@invoicing_list = split( /\s*\,\s*/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');

#create new record object

$new = new FS::cust_main ( {
  map {
    $_, scalar($cgi->param($_))
#  } qw(custnum agentnum last first ss company address1 address2 city county
#       state zip daytime night fax payby payinfo paydate payname tax
#       otaker refnum)
  } fields('cust_main')
} );

$error = $new->check_invoicing_list( \@invoicing_list );

#perhaps the invocing_list magic should move to cust_main.pm?
if ( $new->custnum eq '' ) {
  #false laziness: copied from cust_pkg.pm
  HERE!
  #
  $error ||= $new->insert;
} else { #create old record object
  my $old = qsearchs( 'cust_main', { 'custnum' => $new->custnum } ); 
  $error ||= "Old record not found!" unless $old;
  $error ||= $new->replace($old);
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_main.cgi?". $cgi->query_string );
} else { 
  $new->invoicing_list( \@invoicing_list );
  $custnum = $new->custnum;
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum#cust_main");
} 
