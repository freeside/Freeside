<%
#<!-- $Id: part_pkg.cgi,v 1.7 2001-10-26 10:24:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $p $part_pkg );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::part_pkg;
use FS::pkg_svc;
use FS::part_svc;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( @FS::CGI::header ), header("Package Definition Listing",menubar(
  'Main Menu' => $p,
)), "One or more services are grouped together into a package and given",
  " pricing information. Customers purchase packages",
  " rather than purchase services directly.<BR><BR>", 
  &table(), <<END;
      <TR>
        <TH COLSPAN=2>Package</TH>
        <TH>Comment</TH>
        <TH><FONT SIZE=-1>Freq.</FONT></TH>
        <TH><FONT SIZE=-1>Plan</FONT></TH>
        <TH><FONT SIZE=-1>Data</FONT></TH>
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
  my $plandata;
  if ( $hashref->{plan} ) {
    $plandata = $hashref->{plandata};
    $plandata =~ s/^(\w+)=/$1&nbsp;/mg;
    $plandata =~ s/\n/<BR>/g;
  } else {
    $hashref->{plan} = "(legacy)";
    $plandata = "Setup&nbsp;". $hashref->{setup}.
                "<BR>Recur&nbsp;". $hashref->{recur};
  }
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_pkg.cgi?$hashref->{pkgpart}">
          $hashref->{pkgpart}
        </A></TD>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_pkg.cgi?$hashref->{pkgpart}">$hashref->{pkg}</A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{comment}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{freq}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{plan}</TD>
        <TD ROWSPAN=$rowspan>$plandata</TD>
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
   <TR><TD COLSPAN=8><I><A HREF="${p}edit/part_pkg.cgi">Add a new package definition</A></I></TD></TR>
    </TABLE>
  </BODY>
</HTML>
END
%>
