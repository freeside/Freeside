#!/usr/bin/perl -Tw
#
# $Id: part_pkg.cgi,v 1.4 1998-12-17 05:25:19 ivan Exp $
#
# ivan@sisd.com 97-dec-5,9
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_pkg.cgi,v $
# Revision 1.4  1998-12-17 05:25:19  ivan
# fix visual and other bugs
#
# Revision 1.3  1998/11/21 07:23:45  ivan
# visual
#
# Revision 1.2  1998/11/21 07:00:32  ivan
# visual
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::part_pkg;
use FS::pkg_svc;
use FS::part_svc;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my $p = popurl(2);

print $cgi->header, header("Package Part Listing",menubar(
  'Main Menu' => $p,
)), "One or more services are grouped together into a package and given",
  " pricing information. Customers purchase packages, not services.<BR><BR>", 
  table, <<END;
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

my($part_pkg);
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

