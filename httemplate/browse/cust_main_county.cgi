<!-- mason kludge -->
<%

my $conf = new FS::Conf;
my $enable_taxclasses = $conf->exists('enable_taxclasses');

print header("Tax Rate Listing", menubar(
  'Main Menu' => $p,
  'Edit tax rates' => $p. "edit/cust_main_county.cgi",
)),<<END;
    Click on <u>expand country</u> to specify a country's tax rates by state.
    <BR>Click on <u>expand state</u> to specify a state's tax rates by county.
END

if ( $enable_taxclasses ) {
  print '<BR>Click on <u>expand taxclasses</u> to specify tax classes';
}

print '<BR><BR>'. &table(). <<END;
      <TR>
        <TH><FONT SIZE=-1>Country</FONT></TH>
        <TH><FONT SIZE=-1>State</FONT></TH>
        <TH>County</TH>
        <TH>Taxclass<BR><FONT SIZE=-1>(per-package classification)</FONT></TH>
        <TH>Tax name<BR><FONT SIZE=-1>(printed on invoices)</FONT></TH>
        <TH><FONT SIZE=-1>Tax</FONT></TH>
        <TH><FONT SIZE=-1>Exemption</TH>
      </TR>
END

my @regions = sort {    $a->country  cmp $b->country
                     or $a->state    cmp $b->state
                     or $a->county   cmp $b->county
                     or $a->taxclass cmp $b->taxclass
                   } qsearch('cust_main_county',{});

my $sup=0;
#foreach $cust_main_county ( @regions ) {
for ( my $i=0; $i<@regions; $i++ ) { 
  my $cust_main_county = $regions[$i];
  my $hashref = $cust_main_county->hashref;
  print <<END;
      <TR>
        <TD BGCOLOR="#ffffff">$hashref->{country}</TD>
END

  my $j;
  if ( $sup ) {
    $sup--;
  } else {

    #lookahead
    for ( $j=1; $i+$j<@regions; $j++ ) {
      last if $hashref->{country} ne $regions[$i+$j]->country
           || $hashref->{state} ne $regions[$i+$j]->state
           || $hashref->{tax} != $regions[$i+$j]->tax
           || $hashref->{exempt_amount} != $regions[$i+$j]->exempt_amount
           || $hashref->{setuptax} ne $regions[$i+$j]->setuptax
           || $hashref->{recurtax} ne $regions[$i+$j]->recurtax;
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

    print "<TD ROWSPAN=$j", $hashref->{state}
        ? ' BGCOLOR="#ffffff">'. $hashref->{state}
        : qq! BGCOLOR="#cccccc">(ALL) <FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand country</A></FONT>!;

    print qq! <FONT SIZE=-1><A HREF="${p}edit/process/cust_main_county-collapse.cgi?!. $hashref->{taxnum}. qq!">collapse state</A></FONT>! if $j>1;

    print "</TD>";
  }

#  $sup=$newsup;

  print "<TD";
  if ( $hashref->{county} ) {
    print ' BGCOLOR="#ffffff">'. $hashref->{county};
  } else {
    print ' BGCOLOR="#cccccc">(ALL)';
    if ( $hashref->{state} ) {
      print qq!<FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand state</A></FONT>!;
    }
  }
  print "</TD>";

  print "<TD";
  if ( $hashref->{taxclass} ) {
    print ' BGCOLOR="#ffffff">'. $hashref->{taxclass};
  } else {
    print ' BGCOLOR="#cccccc">(ALL)';
    if ( $enable_taxclasses ) {
      print qq!<FONT SIZE=-1>!.
            qq!<A HREF="${p}edit/cust_main_county-expand.cgi?taxclass!.
            $hashref->{taxnum}. qq!">expand taxclasses</A></FONT>!;
    }

  }
  print "</TD>";

  print "<TD";
  if ( $hashref->{taxname} ) {
    print ' BGCOLOR="#ffffff">'. $hashref->{taxname};
  } else {
    print ' BGCOLOR="#cccccc">Tax';
  }
  print "</TD>";

  print "<TD BGCOLOR=\"#ffffff\">$hashref->{tax}%</TD>".
        '<TD BGCOLOR="#ffffff">';
  print '$'. sprintf("%.2f", $hashref->{exempt_amount} ).
        '&nbsp;per&nbsp;month<BR>'
    if $hashref->{exempt_amount} > 0;
  print 'Setup&nbsp;fee<BR>' if $hashref->{setuptax} =~ /^Y$/i;
  print 'Recurring&nbsp;fee<BR>' if $hashref->{recurtax} =~ /^Y$/i;
  print '</TD></TR>';

}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
