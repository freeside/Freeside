#!/usr/bin/perl -Tw
#
# $Id: part_referral.cgi,v 1.3 1998-12-30 23:03:30 ivan Exp $
#
# ivan@sisd.com 98-feb-23
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_referral.cgi,v $
# Revision 1.3  1998-12-30 23:03:30  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.2  1998/12/17 08:40:25  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::part_referral;
use FS::CGI qw(popurl eidiot);

my($cgi)=new CGI; # create form object

&cgisuidsetup($cgi);

my($refnum)=$cgi->param('refnum');

my($new)=create FS::part_referral ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_referral')
} );

if ( $refnum ) {
  my($old)=qsearchs('part_referral',{'refnum'=>$refnum});
  eidiot("(Old) Record not found!") unless $old;
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
}

$refnum=$new->getfield('refnum');
print $cgi->redirect(popurl(3). "browse/part_referral.cgi");

