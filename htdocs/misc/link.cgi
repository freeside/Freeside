#!/usr/bin/perl -Tw
#
# link: instead of adding a new account, link to an existing. (output form)
#
# Note: Should be run setuid freeside as user nobody
#
# ivan@voicenet.com 97-feb-5
#
# rewrite ivan@sisd.com 98-mar-17
#
# can also link on some other fields now (about time) ivan@sisd.com 98-jun-24

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);

my(%link_field)=(
  'svc_acct'    => 'username',
  'svc_domain'  => 'domain',
  'svc_acct_sm' => '',
  'svc_charge'  => '',
  'svc_wo'      => '',
);

my($cgi) = new CGI::Base;
$cgi->get;
cgisuidsetup($cgi);

my($pkgnum,$svcpart);
foreach $_ (split(/-/,$QUERY_STRING)) { #get & untaint pkgnum & svcpart
  $pkgnum=$1 if /^pkgnum(\d+)$/;
  $svcpart=$1 if /^svcpart(\d+)$/;
}

my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
my($svc) = $part_svc->getfield('svc');
my($svcdb) = $part_svc->getfield('svcdb');
my($link_field) = $link_field{$svcdb};

CGI::Base::SendHeaders();
print <<END;
<HTML>
  <HEAD>
    <TITLE>Link to existing $svc account</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Link to existing $svc account</H1>
    </CENTER><HR>
    <FORM ACTION="process/link.cgi" METHOD=POST>
END

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

