<%
#!/usr/bin/perl -Tw
#
# $Id: part_pkg.cgi,v 1.1 2001-07-30 07:36:03 ivan Exp $
#
# ivan@sisd.com 97-dec-5,9
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_pkg.cgi,v $
# Revision 1.1  2001-07-30 07:36:03  ivan
# templates!!!
#
# Revision 1.8  1999/04/09 04:22:34  ivan
# also table()
#
# Revision 1.7  1999/04/09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.6  1999/01/19 05:13:27  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 09:41:17  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/17 05:25:19  ivan
# fix visual and other bugs
#
# Revision 1.3  1998/11/21 07:23:45  ivan
# visual
#
# Revision 1.2  1998/11/21 07:00:32  ivan
# visual
#

use strict;
use vars qw( $cgi $p $part_pkg );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::part_pkg;
use FS::pkg_svc;
use FS::part_svc;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("Package Part Listing",menubar(
  'Main Menu' => $p,
)), "One or more services are grouped together into a package and given",
  " pricing information. Customers purchase packages, not services.<BR><BR>", 
  &table(), <<END;
    <TABLE BORDER>
      <TR>
        <TH COLSPAN=2>Package</TH>
        <TH>Comment</TH>
        <TH><FONT SIZE=-1>Setup Fee</FONT></TH>
        <TH><FONT SIZE=-1>Freq.</FONT></TH>
        <TH><FONT SIZE=-1>Recur. Fee</FONT></TH>
        <TH>Service</TH>
        <TH><FONT SIZE=-1>Quan.</FONT></TH>
      </TR>
END

foreach $part_pkg ( sort { 
  $a->getfield('pkgpart') <=> $b->getfield('pkgpart')
} qsearch('part_pkg',{}) ) {
  my($hashref)=$part_pkg->hashref;
  my(@pkg_svc)=grep $_->getfield('quantity'),
    qsearch('pkg_svc',{'pkgpart'=> $hashref->{pkgpart} });
  my($rowspan)=scalar(@pkg_svc);
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_pkg.cgi?$hashref->{pkgpart}">
          $hashref->{pkgpart}
        </A></TD>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_pkg.cgi?$hashref->{pkgpart}">$hashref->{pkg}</A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{comment}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{setup}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{freq}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{recur}</TD>
END

  my($pkg_svc);
  my($n)="";
  foreach $pkg_svc ( @pkg_svc ) {
    my($svcpart)=$pkg_svc->getfield('svcpart');
    my($part_svc) = qsearchs('part_svc',{'svcpart'=> $svcpart });
    print $n,qq!<TD><A HREF="${p}edit/part_svc.cgi?$svcpart">!,
          $part_svc->getfield('svc'),"</A></TD><TD>",
          $pkg_svc->getfield('quantity'),"</TD></TR>\n";
    $n="<TR>";
  }

  print "</TR>";
}

print <<END;
   <TR><TD COLSPAN=2><I><A HREF="${p}edit/part_pkg.cgi">Add new package</A></I></TD></TR>
    </TABLE>
  </BODY>
</HTML>
END
%>
