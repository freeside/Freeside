#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.4 1999-01-18 09:22:32 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_main.cgi
#
# Note: Should be run setuid root as user nobody.
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
# Revision 1.4  1999-01-18 09:22:32  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.3  1998/12/17 08:40:19  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/18 08:57:36  ivan
# i18n, s/CGI-modules/CGI.pm/, FS::CGI::idiot instead of inline, FS::CGI::popurl
#

use strict;
#use CGI;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(eidiot popurl);
use FS::Record qw(qsearchs fields);
use FS::cust_main;

my($cgi)=new CGI;
&cgisuidsetup($cgi);

#unmunge stuff

$cgi->param('agentnum', (split(/:/, ($cgi->param('agentnum'))[0] ))[0] );

$cgi->param('tax','') unless defined($cgi->param('tax'));

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

$cgi->param('state') =~ /^(\w+)( \((\w+)\))? \/ (\w+)$/;
$cgi->param('state', $1);
$cgi->param('county', $3 || '');
$cgi->param('country', $4);

my $payby = $cgi->param('payby');
$cgi->param('payinfo', $cgi->param( $payby. '_payinfo' ) );
$cgi->param('paydate',
  $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' ) );
$cgi->param('payname', $cgi->param( $payby. '_payname' ) );

$cgi->param('otaker', &getotaker );

my @invoicing_list = split( /\s*\,\s*/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');

#create new record object

my($new) = new FS::cust_main ( {
  map {
    $_, scalar($cgi->param($_))
#  } qw(custnum agentnum last first ss company address1 address2 city county
#       state zip daytime night fax payby payinfo paydate payname tax
#       otaker refnum)
  } fields('cust_main')
} );

#perhaps the invocing_list magic should move to cust_main.pm?
if ( $new->custnum eq '' ) {
  my $error;
  $error = $new->check_invoicing_list( \@invoicing_list );
  &ediot($error) if $error;
  $error = $new->insert;
  &eidiot($error) if $error;
  $new->invoicing_list( \@invoicing_list );
} else { #create old record object
  my $error;
  my $old = qsearchs( 'cust_main', { 'custnum' => $new->custnum } ); 
  &eidiot("Old record not found!") unless $old;
  $error = $new->check_invoicing_list( \@invoicing_list );
  &eidiot($error) if $error;
  $error = $new->replace($old);
  &eidiot($error) if $error;
  $new->invoicing_list( \@invoicing_list );
}

my $custnum = $new->custnum;
print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum#cust_main");

