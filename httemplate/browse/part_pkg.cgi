<%

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_pkg = qsearch('part_pkg', \%search );
my $total = scalar(@part_pkg);

print header("Package Definition Listing",menubar(
  'Main Menu' => $p,
)). "One or more services are grouped together into a package and given".
  " pricing information. Customers purchase packages".
  " rather than purchase services directly.<BR><BR>".
  "$total packages ";

if ( $cgi->param('showdisabled') ) {
  $cgi->param('showdisabled', 0);
  print qq!( <a href="!. $cgi->self_url. qq!">hide disabled packages</a> )!;
} else {
  $cgi->param('showdisabled', 1);
  print qq!( <a href="!. $cgi->self_url. qq!">show disabled packages</a> )!;
}

my $colspan = $cgi->param('showdisabled') ? 2 : 3;
print &table(), <<END;
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

foreach my $part_pkg ( sort { 
  $a->getfield('pkgpart') <=> $b->getfield('pkgpart')
} @part_pkg ) {
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
        <TD ROWSPAN=$rowspan><A HREF="${p}edit/part_pkg.cgi?$hashref->{pkgpart}">$hashref->{pkgpart}</A></TD>
END

  unless ( $cgi->param('showdisabled') ) {
    print "<TD ROWSPAN=$rowspan>";
    print "DISABLED" if $hashref->{disabled};
    print '</TD>';
  }

  print <<END;
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
