#!/usr/bin/perl -Tw
#
# $Id: agent_type.cgi,v 1.7 1999-04-09 03:52:55 ivan Exp $
#
# ivan@sisd.com 97-dec-10
#
# Changes to allow page to work at a relative position in server
# Changes to make "Packages" display 2-wide in table (old way was too vertical)
#	bmccane@maxbaud.net 98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: agent_type.cgi,v $
# Revision 1.7  1999-04-09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.6  1999/04/07 11:10:46  ivan
# harmless typo
#
# Revision 1.5  1999/01/19 05:13:25  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:15  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 05:25:17  ivan
# fix visual and other bugs
#
# Revision 1.2  1998/11/21 07:39:52  ivan
# visual
#

use strict;
use vars qw( $cgi $p $agent_type );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::agent_type;
use FS::type_pkgs;
use FS::part_pkg;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);
print $cgi->header( '-expires' => 'now' ), header("Agent Type Listing", menubar(
  'Main Menu' => $p,
)), "Agent types define groups of packages that you can then assign to".
    " particular agents.<BR><BR>", &table, <<END;
      <TR>
        <TH COLSPAN=2>Agent Type</TH>
        <TH COLSPAN="2">Packages</TH>
      </TR>
END

foreach $agent_type ( sort { 
  $a->getfield('typenum') <=> $b->getfield('typenum')
} qsearch('agent_type',{}) ) {
  my($hashref)=$agent_type->hashref;
  my(@type_pkgs)=qsearch('type_pkgs',{'typenum'=> $hashref->{typenum} });
  my($rowspan)=scalar(@type_pkgs);
  $rowspan = int($rowspan/2+0.5) ;
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/agent_type.cgi?$hashref->{typenum}">
          $hashref->{typenum}
        </A></TD>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/agent_type.cgi?$hashref->{typenum}">$hashref->{atype}</A></TD>
END

  my($type_pkgs);
  my($tdcount) = -1 ;
  foreach $type_pkgs ( @type_pkgs ) {
    my($pkgpart)=$type_pkgs->getfield('pkgpart');
    my($part_pkg) = qsearchs('part_pkg',{'pkgpart'=> $pkgpart });
    print qq!<TR>! if ($tdcount == 0) ;
    $tdcount = 0 if ($tdcount == -1) ;
    print qq!<TD><A HREF="${p}edit/part_pkg.cgi?$pkgpart">!,
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
  <TR><TD COLSPAN=2><I><A HREF="${p}edit/agent_type.cgi">Add new agent type</A></I></TD></TR>
    </TABLE>
  </BODY>
</HTML>
END

