#!/usr/bin/perl -Tw
#
# $Id: part_svc.cgi,v 1.10 1999-04-09 03:52:55 ivan Exp $
#
# ivan@sisd.com 97-nov-14, 97-dec-9
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_svc.cgi,v $
# Revision 1.10  1999-04-09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.9  1999/01/19 05:13:29  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.8  1999/01/18 09:41:19  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.7  1998/12/30 23:06:22  ivan
# typo
#
# Revision 1.6  1998/12/30 23:03:20  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.5  1998/12/17 05:25:21  ivan
# fix visual and other bugs
#
# Revision 1.4  1998/11/21 02:26:22  ivan
# visual
#
# Revision 1.3  1998/11/20 23:10:57  ivan
# visual
#
# Revision 1.2  1998/11/20 08:50:37  ivan
# s/CGI::Base/CGI.pm, visual fixes
#

use strict;
use vars qw( $cgi $p $part_svc );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch fields);
use FS::part_svc;
use FS::CGI qw(header menubar popurl table);

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header('Service Part Listing', menubar(
  'Main Menu' => $p,
)),<<END;
    Services are items you offer to your customers.<BR><BR>
END
print &table, <<END;
      <TR>
        <TH COLSPAN=2>Service</TH>
        <TH>Table</TH>
        <TH>Field</TH>
        <TH COLSPAN=2>Modifier</TH>
      </TR>
END

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
  my($rowspan)=scalar(@rows) || 1;
  print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_svc.cgi?$hashref->{svcpart}">
          $hashref->{svcpart}</A></TD>
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_svc.cgi?$hashref->{svcpart}">          $hashref->{svc}</A></TD>
        <TD ROWSPAN=$rowspan>$hashref->{svcdb}</TD>
END

  my($n1)='';
  my($row);
  foreach $row ( @rows ) {
    my($flag)=$part_svc->getfield($svcdb.'__'.$row.'_flag');
    print $n1,"<TD>$row</TD><TD>";
    if ( $flag eq "D" ) { print "Default"; }
      elsif ( $flag eq "F" ) { print "Fixed"; }
      else { print "(Unknown!)"; }
    print "</TD><TD>",$part_svc->getfield($svcdb."__".$row),"</TD>";
    $n1="</TR><TR>";
  }
print "</TR>";
}

print <<END;
      <TR>
        <TD COLSPAN=2><A HREF="${p}edit/part_svc.cgi"><I>Add new service</I></A></TD>
      </TR>
    </TABLE>
  </BODY>
</HTML>
END

