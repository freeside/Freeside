#!/usr/bin/perl -Tw
#
# $Id: svc_domain.cgi,v 1.10 2001-04-23 07:12:44 ivan Exp $
#
# Usage: svc_domain.cgi pkgnum{pkgnum}-svcpart{svcpart}
#        http://server.name/path/svc_domain.cgi?pkgnum{pkgnum}-svcpart{svcpart}
#
# ivan@voicenet.com 97-jan-5 -> 97-jan-6
#
# changes for domain template 3.5
# ivan@voicenet.com 97-jul-24
#
# rewrite ivan@sisd.com 98-mar-14
#
# no GOV in instructions ivan@sisd.com 98-jul-17
#
# $Log: svc_domain.cgi,v $
# Revision 1.10  2001-04-23 07:12:44  ivan
# better error message (if kludgy) for no referral
# remove outdated NSI foo from domain ordering.  also, fuck NSI.
#
# Revision 1.9  1999/02/28 00:03:39  ivan
# removed misleading comments
#
# Revision 1.8  1999/02/07 09:59:25  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.7  1999/01/19 05:13:46  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 09:41:35  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.5  1998/12/30 23:03:25  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.4  1998/12/23 03:00:16  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.3  1998/12/17 06:17:12  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/13 09:56:48  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use vars qw( $cgi $action $svcnum $svc_domain $pkgnum $svcpart $part_svc
             $svc $otaker $domain $p1 $kludge_action $purpose );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_domain;

$cgi = new CGI;
&cgisuidsetup($cgi);

if ( $cgi->param('error') ) {
  $svc_domain = new FS::svc_domain ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_domain')
  } );
  $svcnum = $svc_domain->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $kludge_action = $cgi->param('action');
  $purpose = $cgi->param('purpose');
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry!" unless $part_svc;
} else {
  $kludge_action = '';
  $purpose = '';
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
      or die "Unknown (svc_domain) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;

    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_domain = new FS::svc_domain({});
  
    foreach $_ (split(/-/,$query)) {
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

  }
}
$action = $svcnum ? 'Edit' : 'Add';

$svc = $part_svc->getfield('svc');

$otaker = getotaker;

$domain = $svc_domain->domain;

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("$action $svc", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END;
    <FORM ACTION="${p1}process/svc_domain.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
END

print qq!<INPUT TYPE="radio" NAME="action" VALUE="N"!;
print ' CHECKED' if $kludge_action eq 'N';
print qq!>New!;
print qq!<BR><INPUT TYPE="radio" NAME="action" VALUE="M"!;
print ' CHECKED' if $kludge_action eq 'M';
print qq!>Transfer!;

print <<END;
<P>Domain <INPUT TYPE="text" NAME="domain" VALUE="$domain" SIZE=28 MAXLENGTH=26>
<BR>Purpose/Description: <INPUT TYPE="text" NAME="purpose" VALUE="$purpose" SIZE=64>
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
<!--  <P>GOV registrations are limited to top-level US Federal Government agencies (see RFC 1816).
!-->
    </FORM>
  </BODY>
</HTML>
END

