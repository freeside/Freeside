<%
#<!-- $Id: queue.cgi,v 1.1 2001-09-11 04:44:58 ivan Exp $ -->

use strict;
use vars qw( $cgi $p ); # $part_referral );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Date::Format;
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch);
use FS::CGI qw(header menubar popurl table);
use FS::queue;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("Job Queue", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)), &table(), <<END;
      <TR>
        <TH COLSPAN=2>Job</TH>
        <TH>Args</TH>
        <TH>Date</TH>
        <TH>Status</TH>
      </TR>
END

foreach my $queue ( sort { 
  $a->getfield('jobnum') <=> $b->getfield('jobnum')
} qsearch('queue',{}) ) {
  my($hashref)=$queue->hashref;
  my $args = join(' ', $queue->args);
  my $date = time2str( "%a %b %e %T %Y", $queue->_date );
  print <<END;
      <TR>
        <TD>$hashref->{jobnum}</TD>
        <TD>$hashref->{job}</TD>
        <TD>$args</TD>
        <TD>$date</TD>
        <TD>$hashref->{status}</TD>
      </TR>
END

}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
