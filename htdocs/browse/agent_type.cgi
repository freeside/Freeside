#!/usr/bin/perl -Tw
#
# agent_type.cgi: browse agent_type
#
# ivan@sisd.com 97-dec-10
#
# Changes to allow page to work at a relative position in server
# Changes to make "Packages" display 2-wide in table (old way was too vertical)
#	bmccane@maxbaud.net 98-apr-3
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

print header("Agent Type Listing", menubar(
  'Main Menu' => '../',
  'Add new agent type' => "../edit/agent_type.cgi",
)), <<END;
    <BR>Click on agent type number to edit.
    <TABLE BORDER>
      <TR>
        <TH><FONT SIZE=-1>Type #</FONT></TH>
        <TH>Type</TH>
        <TH colspan="2">Packages</TH>
      </TR>
END

my($agent_type);
foreach $agent_type ( sort { 
  $a->getfield('typenum') <=> $b->getfield('typenum')
} qsearch('agent_type',{}) ) {
  my($hashref)=$agent_type->hashref;
  my(@type_pkgs)=qsearch('type_pkgs',{'typenum'=> $hashref->{typenum} });
  my($rowspan)=scalar(@type_pkgs);
  $rowspan = int($rowspan/2+0.5) ;
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="../edit/agent_type.cgi?$hashref->{typenum}">
          $hashref->{typenum}
        </A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{atype}</TD>
END

  my($type_pkgs);
  my($tdcount) = -1 ;
  foreach $type_pkgs ( @type_pkgs ) {
    my($pkgpart)=$type_pkgs->getfield('pkgpart');
    my($part_pkg) = qsearchs('part_pkg',{'pkgpart'=> $pkgpart });
    print qq!<TR>! if ($tdcount == 0) ;
    $tdcount = 0 if ($tdcount == -1) ;
    print qq!<TD><A HREF="../edit/part_pkg.cgi?$pkgpart">!,
          $part_pkg->getfield('pkg'),"</A></TD>";
    $tdcount ++ ;
    if ($tdcount == 2)
    {
	print qq!</TR>\n! ;
	$tdcount = 0 ;
    }
  }

  print "</TR>";
}

print <<END;
    </TR></TABLE>
    </CENTER>
  </BODY>
</HTML>
END

