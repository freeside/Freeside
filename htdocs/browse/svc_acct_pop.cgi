#!/usr/bin/perl -Tw
#
# $Id: svc_acct_pop.cgi,v 1.2 1998-12-17 04:36:59 ivan Exp $
#
# ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: svc_acct_pop.cgi,v $
# Revision 1.2  1998-12-17 04:36:59  ivan
# use CGI;, use CGI::Carp, visual changes, relative URLs
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar table popurl);

my($cgi) = new CGI;

&cgisuidsetup($cgi);

print $cgi->header, header('POP Listing', menubar(
  'Main Menu' => popurl(2),
)), table, <<END;
      <TR>
        <TH></TH>
        <TH>City</TH>
        <TH>State</TH>
        <TH>Area code</TH>
        <TH>Exchange</TH>
      </TR>
END

my($svc_acct_pop);
my($p)=popurl(2);
foreach $svc_acct_pop ( sort { 
  $a->getfield('popnum') <=> $b->getfield('popnum')
} qsearch('svc_acct_pop',{}) ) {
  my($hashref)=$svc_acct_pop->hashref;
  print <<END;
      <TR>
        <TD><A HREF="$p/edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{popnum}</A></TD>
        <TD><A HREF="$p/edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{city}</A></TD>
        <TD><A HREF="$p/edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{state}</A></TD>
        <TD><A HREF="$p/edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{ac}</A></TD>
        <TD><A HREF="$p/edit/svc_acct_pop.cgi?$hashref->{popnum}">
          $hashref->{exch}</A></TD>
      </TR>
END

}

print <<END;
      <TR>
        <TD COLSPAN=5><A HREF="$p/edit/svc_acct_pop.cgi"><I>Add new POP</I></A></TD>
      </TR>
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

