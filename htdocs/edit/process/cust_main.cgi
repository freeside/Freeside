#!/usr/bin/perl -Tw
#
# process/cust_main.cgi: Edit a customer (process form)
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

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::cust_main;

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

#create new record object

#unmunge agentnum
$req->param('agentnum', 
  (split(/:/, ($req->param('agentnum'))[0] ))[0]
);

#unmunge tax
$req->param('tax','') unless defined($req->param('tax'));

#unmunge refnum
$req->param('refnum',
  (split(/:/, ($req->param('refnum'))[0] ))[0]
);

#unmunge state/county
$req->param('state') =~ /^(\w+)( \((\w+)\))?$/;
$req->param('state', $1);
$req->param('county', $3 || '');

my($new) = create FS::cust_main ( {
  map {
    $_, $req->param("$_") || ''
  } qw(custnum agentnum last first ss company address1 address2 city county
       state zip country daytime night fax payby payinfo paydate payname tax
       otaker refnum)
} );

if ( $new->custnum eq '' ) {

  my($error)=$new->insert;
  &idiot($error) if $error;

} else { #create old record object

  my($old) = qsearchs( 'cust_main', { 'custnum', $new->custnum } ); 
  &idiot("Old record not found!") unless $old;
  my($error)=$new->replace($old);
  &idiot($error) if $error;

}

my($custnum)=$new->custnum;
$req->cgi->redirect("../../view/cust_main.cgi?$custnum#cust_main");

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error updating customer information</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error updating customer information</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END

  exit;

}

