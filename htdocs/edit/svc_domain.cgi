#!/usr/bin/perl -Tw
#
# svc_domain.cgi: Add domain (output form)
#
# Usage: svc_domain.cgi pkgnum{pkgnum}-svcpart{svcpart}
#        http://server.name/path/svc_domain.cgi?pkgnum{pkgnum}-svcpart{svcpart}
#
# Note: Should be run setuid freeside as user nobody
#
# ivan@voicenet.com 97-jan-5 -> 97-jan-6
#
# changes for domain template 3.5
# ivan@voicenet.com 97-jul-24
#
# rewrite ivan@sisd.com 98-mar-14
#
# no GOV in instructions ivan@sisd.com 98-jul-17

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup getotaker);
use FS::Record qw(qsearch qsearchs);
use FS::svc_domain qw(fields);

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);

my($action,$svcnum,$svc_domain,$pkgnum,$svcpart,$part_svc);

if ( $QUERY_STRING =~ /^(\d+)$/ ) { #editing

  $svcnum=$1;
  $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
    or die "Unknown (svc_domain) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $action="Edit";

} else { #adding

  $svc_domain=create FS::svc_domain({});
  
  foreach $_ (split(/-/,$QUERY_STRING)) {
    $pkgnum=$1 if /^pkgnum(\d+)$/;
    $svcpart=$1 if /^svcpart(\d+)$/;
  }
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svcnum='';

  #set fixed and default fields from part_svc
  my($field);
  foreach $field ( fields('svc_domain') ) {
    if ( $part_svc->getfield('svc_domain__'. $field. '_flag') ne '' ) {
      $svc_domain->setfield($field,$part_svc->getfield('svc_domain__'. $field) );
    }
  }

  $action="Add";

}

my($svc)=$part_svc->getfield('svc');

my($otaker)=getotaker;

my($domain)=(
  $svc_domain->domain,
);

SendHeaders();
print <<END;
<HTML>
  <HEAD>
    <TITLE>$action $svc</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>$action $svc</H1>
    </CENTER><HR>
    <FORM ACTION="process/svc_domain.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
      <INPUT TYPE="radio" NAME="action" VALUE="N">New
      <BR><INPUT TYPE="radio" NAME="action" VALUE="M">Transfer

<P>Customer agrees to be bound by NSI's
<A HREF="http://rs.internic.net/help/agreement.txt">
Domain Name Registration Agreement</A>
<SELECT NAME="legal" SIZE=1><OPTION SELECTED>No<OPTION>Yes</SELECT>
<P>Domain <INPUT TYPE="text" NAME="domain" VALUE="$domain" SIZE=28 MAXLENGTH=26>
<BR>Purpose/Description: <INPUT TYPE="text" NAME="purpose" VALUE="" SIZE=64>
<P><CENTER><INPUT TYPE="submit" VALUE="Submit"></CENTER>
<UL>
  <LI>COM is for commercial, for-profit organziations
  <LI>ORG is for miscellaneous, usually, non-profit organizations
  <LI>NET is for network infrastructure machines and organizations
  <LI>EDU is for 4-year, degree granting institutions
<!--  <LI>GOV is for United States federal government agencies
!-->
</UL>
US state and local government agencies, schools, libraries, museums, and individuals should register under the US domain.  See RFC 1480 for a complete description of the US domain
and registration procedures.
<P>GOV registrations are limited to top-level US Federal Government agencies (see RFC 1816).
    </FORM>
  </BODY>
</HTML>
END

