#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.2 1998-11-18 08:57:36 ivan Exp $
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
# Revision 1.2  1998-11-18 08:57:36  ivan
# i18n, s/CGI-modules/CGI.pm/, FS::CGI::idiot instead of inline, FS::CGI::popurl
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(eidiot popurl);
use FS::Record qw(qsearchs);
use FS::cust_main;

my($req)=new CGI;

&cgisuidsetup($cgi);

#create new record object

#unmunge agentnum
$cgi->param('agentnum', 
  (split(/:/, ($cgi->param('agentnum'))[0] ))[0]
);

#unmunge tax
$cgi->param('tax','') unless defined($cgi->param('tax'));

#unmunge refnum
$cgi->param('refnum',
  (split(/:/, ($cgi->param('refnum'))[0] ))[0]
);

#unmunge state/county/country
$cgi->param('state') =~ /^(\w+)( \((\w+)\))? \/ (\w+)$/;
$cgi->param('state', $1);
$cgi->param('county', $3 || '');
$cgi->param('country', $4);

my($new) = create FS::cust_main ( {
  map {
    $_, $cgi->param("$_") || ''
  } qw(custnum agentnum last first ss company address1 address2 city county
       state zip daytime night fax payby payinfo paydate payname tax
       otaker refnum)
} );

if ( $new->custnum eq '' ) {

  my($error)=$new->insert;
  &eidiot($error) if $error;

} else { #create old record object

  my($old) = qsearchs( 'cust_main', { 'custnum', $new->custnum } ); 
  &eidiot("Old record not found!") unless $old;
  my($error)=$new->replace($old);
  &eidiot($error) if $error;

}

my($custnum)=$new->custnum;
print $cgi->redirect(popurl(3). "/view/cust_main.cgi?$custnum#cust_main");

