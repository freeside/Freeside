<%
#<!-- $Id: svc_domain.cgi,v 1.3 2001-09-11 23:44:01 ivan Exp $ -->

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
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_domain->setfield( $part_svc_column->columnname,
                             $part_svc_column->columnvalue,
                           );
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

%>
