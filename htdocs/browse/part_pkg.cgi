#!/usr/bin/perl -Tw
#
# part_svc.cgi: browse part_pkg
#
# ivan@sisd.com 97-dec-5,9
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

print header("Package Part Listing",menubar(
  'Main Menu' => '../',
  'Add new package' => "../edit/part_pkg.cgi",
)), <<END;
    <BR>Click on package part number to edit.
    <TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>Part #</FONT></TH>
        <TH>Package</TH>
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
        <TD ROWSPAN=$rowspan><A HREF="../edit/part_pkg.cgi?$hashref->{pkgpart}">
          $hashref->{pkgpart}
        </A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{pkg}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{comment}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{setup}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{freq}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{recur}</TD>
END

  my($pkg_svc);
  foreach $pkg_svc ( @pkg_svc ) {
    my($svcpart)=$pkg_svc->getfield('svcpart');
    my($part_svc) = qsearchs('part_svc',{'svcpart'=> $svcpart });
    print qq!<TD><A HREF="../edit/part_svc.cgi?$svcpart">!,
          $part_svc->getfield('svc'),"</A></TD><TD>",
          $pkg_svc->getfield('quantity'),"</TD></TR><TR>\n";
  }

  print "</TR>";
}

print <<END;
    </TR></TABLE>
    </CENTER>
  </BODY>
</HTML>
END

