<%
#<!-- $Id: cust_main_county.cgi,v 1.2 2001-08-17 11:05:31 ivan Exp $ -->

use strict;
use vars qw( $cgi $p $cust_main_county );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup swapuid);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl table);
use FS::cust_main_county;

$cgi = new CGI;

&cgisuidsetup($cgi);

$p = popurl(2);

print $cgi->header( '-expires' => 'now' ), header("Tax Rate Listing", menubar(
  'Main Menu' => $p,
  'Edit tax rates' => $p. "edit/cust_main_county.cgi",
)),<<END;
    Click on <u>expand country</u> to specify a country's tax rates by state.
    <BR>Click on <u>expand state</u> to specify a state's tax rates by county.
    <BR><BR>
END
print &table(), <<END;
      <TR>
        <TH><FONT SIZE=-1>Country</FONT></TH>
        <TH><FONT SIZE=-1>State</FONT></TH>
        <TH>County</TH>
        <TH><FONT SIZE=-1>Tax</FONT></TH>
      </TR>
END

my @regions = sort {    $a->country cmp $b->country
                     or $a->state   cmp $b->state
                     or $a->county  cmp $b->county
                   } qsearch('cust_main_county',{});

my $sup=0;
#foreach $cust_main_county ( @regions ) {
for ( my $i=0; $i<@regions; $i++ ) { 
  my $cust_main_county = $regions[$i];
  my $hashref = $cust_main_county->hashref;
  print <<END;
      <TR>
        <TD>$hashref->{country}</TD>
END

  my $j;
  if ( $sup ) {
    $sup--;
  } else {

    #lookahead
    for ( $j=1; $i+$j<@regions; $j++ ) {
      last if $hashref->{country} ne $regions[$i+$j]->country
           || $hashref->{state} ne $regions[$i+$j]->state
           || $hashref->{tax} != $regions[$i+$j]->tax;
    }

    my $newsup=0;
    if ( $j>1 && $i+$j+1 < @regions
         && ( $hashref->{state} ne $regions[$i+$j+1]->state 
              || $hashref->{country} ne $regions[$i+$j+1]->country
              )
         && ( ! $i
              || $hashref->{state} ne $regions[$i-1]->state 
              || $hashref->{country} ne $regions[$i-1]->country
              )
       ) {
       $sup = $j-1;
    } else {
      $j = 1;
    }

    print "<TD ROWSPAN=$j>", $hashref->{state}
        ? $hashref->{state}
        : qq!(ALL) <FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand country</A></FONT>!;

    print qq! <FONT SIZE=-1><A HREF="${p}edit/process/cust_main_county-collapse.cgi?!. $hashref->{taxnum}. qq!">collapse state</A></FONT>! if $j>1;

    print "</TD>";
  }

#  $sup=$newsup;

  print "<TD>";
  if ( $hashref->{county} ) {
    print $hashref->{county};
  } else {
    print "(ALL)";
    if ( $hashref->{state} ) {
      print qq!<FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand state</A></FONT>!;
    }
  }
  print "</TD>";

  print <<END;
        <TD>$hashref->{tax}%</TD>
      </TR>
END

}

print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

%>
