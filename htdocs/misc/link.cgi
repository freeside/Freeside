#!/usr/bin/perl -Tw
#
# $Id: link.cgi,v 1.4 1999-01-18 09:41:36 ivan Exp $
#
# Note: Should be run setuid freeside as user nobody
#
# ivan@voicenet.com 97-feb-5
#
# rewrite ivan@sisd.com 98-mar-17
#
# can also link on some other fields now (about time) ivan@sisd.com 98-jun-24
#
# $Log: link.cgi,v $
# Revision 1.4  1999-01-18 09:41:36  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/23 03:03:39  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:45  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearchs);

my(%link_field)=(
  'svc_acct'    => 'username',
  'svc_domain'  => 'domain',
  'svc_acct_sm' => '',
  'svc_charge'  => '',
  'svc_wo'      => '',
);

my($cgi) = new CGI;
cgisuidsetup($cgi);

my($pkgnum,$svcpart);
my($query) = $cgi->keywords;
foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
  $pkgnum=$1 if /^pkgnum(\d+)$/;
  $svcpart=$1 if /^svcpart(\d+)$/;
}

my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
my($svc) = $part_svc->getfield('svc');
my($svcdb) = $part_svc->getfield('svcdb');
my($link_field) = $link_field{$svcdb};

print $cgi->header( '-expires' => 'now' ), header("Link to existing $svc account"),
      qq!<FORM ACTION="!, popurl(1), qq!process/link.cgi" METHOD=POST>!;

if ( $link_field ) { 
  print <<END;
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="">
  <INPUT TYPE="hidden" NAME="link_field" VALUE="$link_field">
  $link_field of existing service: <INPUT TYPE="text" NAME="link_value">
END
} else {
  print qq!Service # of existing service: <INPUT TYPE="text" NAME="svcnum" VALUE="">!;
}

print <<END;
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
<P><CENTER><INPUT TYPE="submit" VALUE="Link"></CENTER>
    </FORM>
  </BODY>
</HTML>
END

