#!/usr/bin/perl -Tw
#
# part_svc.cgi: browse part_svc
#
# ivan@sisd.com 97-nov-14, 97-dec-9
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Base;
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch);
use FS::part_svc qw(fields);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.
print header('Service Part Listing', menubar(
  'Main Menu' => '../',
  'Add new service' => "../edit/part_svc.cgi",
)),<<END;
    <BR>Click on service part number to edit.
    <TABLE BORDER>
      <TR>
        <TH>Part #</TH>
        <TH>Service</TH>
        <TH>Table</TH>
        <TH>Field</TH>
        <TH>Action</TH>
        <TH>Value</TH>
      </TR>
END

my($part_svc);
foreach $part_svc ( sort {
  $a->getfield('svcpart') <=> $b->getfield('svcpart')
} qsearch('part_svc',{}) ) {
  my($hashref)=$part_svc->hashref;
  my($svcdb)=$hashref->{svcdb};
  my(@rows)=
    grep $hashref->{${svcdb}.'__'.$_.'_flag'},
      map { /^${svcdb}__(.*)$/; $1 }
        grep ! /_flag$/,
          grep /^${svcdb}__/,
            fields('part_svc')
  ;
  my($rowspan)=scalar(@rows);
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="../edit/part_svc.cgi?$hashref->{svcpart}">
          $hashref->{svcpart}
        </A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{svc}</TD>
        <TD ROWSPAN=$rowspan>$hashref->{svcdb}</TD>
END
  my($row);
  foreach $row ( @rows ) {
    my($flag)=$part_svc->getfield($svcdb.'__'.$row.'_flag');
    print "<TD>$row</TD><TD>";
    if ( $flag eq "D" ) { print "Default"; }
      elsif ( $flag eq "F" ) { print "Fixed"; }
      else { print "(Unknown!)"; }
    print "</TD><TD>",$part_svc->getfield($svcdb."__".$row),"</TD></TR><TR>";
  }
print "</TR>";
}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

