<%
# <!-- $Id: cust_pkg.cgi,v 1.3 2001-08-19 08:32:43 ivan Exp $ -->

use strict;
use vars qw ( $cgi @cust_pkg $sortby $query %part_pkg );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs dbdef);
use FS::CGI qw(header eidiot popurl table);
use FS::cust_pkg;
use FS::pkg_svc;
use FS::cust_svc;
use FS::cust_main;

$cgi = new CGI;
&cgisuidsetup($cgi);

my %part_pkg = map { $_->pkgpart => $_ } qsearch('part_pkg', {});

($query) = $cgi->keywords;
#this tree is a little bit redundant
if ( $query eq 'pkgnum' ) {
  $sortby=\*pkgnum_sort;
  @cust_pkg=qsearch('cust_pkg',{});
} elsif ( $query eq 'APKG_pkgnum' ) {
  $sortby=\*pkgnum_sort;
  @cust_pkg=();
  #perhaps this should go in cust_pkg as a qsearch-like constructor?
  my($cust_pkg);
  foreach $cust_pkg (qsearch('cust_pkg',{})) {
    my($flag)=0;
    my($pkg_svc);
    PKG_SVC: 
    foreach $pkg_svc (qsearch('pkg_svc',{ 'pkgpart' => $cust_pkg->pkgpart })) {
      if ( $pkg_svc->quantity 
           > scalar(qsearch('cust_svc',{
               'pkgnum' => $cust_pkg->pkgnum,
               'svcpart' => $pkg_svc->svcpart,
             }))
         )
      {
        $flag=1;
        last PKG_SVC;
      }
    }
    push @cust_pkg, $cust_pkg if $flag;
  }
} else {
  die "Empty QUERY_STRING!";
}

if ( scalar(@cust_pkg) == 1 ) {
  my($pkgnum)=$cust_pkg[0]->pkgnum;
  print $cgi->redirect(popurl(2). "view/cust_pkg.cgi?$pkgnum");
  exit;
} elsif ( scalar(@cust_pkg) == 0 ) { #error
  eidiot("No packages found");
} else {
  my($total)=scalar(@cust_pkg);
  print $cgi->header( '-expires' => 'now' ),
        header('Package Search Results',''),
        "$total matching packages found<BR>", &table(), <<END;
      <TR>
        <TH>Package</TH>
        <TH><FONT SIZE=-1>Cust#</FONT></TH>
        <TH>(bill) name</TH>
        <TH>company</TH>
END

if ( defined dbdef->table('cust_main')->column('ship_last') ) {
  print <<END;
      <TH>(service) name</TH>
      <TH>company</TH>
END
}

print <<END;
        <TH COLSPAN=2>Services</TH>
      </TR>
END

  my $n1 = '<TR>';
  my(%saw,$cust_pkg);
  foreach $cust_pkg (
    sort $sortby grep(!$saw{$_->pkgnum}++, @cust_pkg)
  ) {
    my($cust_main)=qsearchs('cust_main',{'custnum'=>$cust_pkg->custnum});
    my($pkgnum, $custnum, $last, $first, $company,
       $ship_last, $ship_first, $ship_company)=(
      $cust_pkg->pkgnum,
      $cust_pkg->custnum,
      $cust_main ? $cust_main->last : '',
      $cust_main ? $cust_main->first : '',
      $cust_main ? $cust_main->company : '',
      $cust_main
        ? ( $cust_main->ship_last || $cust_main->getfield('last') )
        : '',
      $cust_main 
        ? ( $cust_main->ship_last
            ? $cust_main->ship_first
            : $cust_main->first )
        : '',
      $cust_main 
        ? ( $cust_main->ship_last
            ? $cust_main->ship_company
            : $cust_main->company )
        : '',
    );
    my $pkg = $part_pkg{$cust_pkg->pkgpart}->pkg;
    #$pkg .= ' - '. $part_pkg{$cust_pkg->pkgpart}->comment;
    my @cust_svc = qsearch( 'cust_svc', { 'pkgnum' => $pkgnum } );
    my $rowspan = scalar(@cust_svc) || 1;
    my $p = popurl(2);
    print $n1, <<END;
      <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_pkg.cgi?$pkgnum"><FONT SIZE=-1>$pkgnum - $pkg</FONT></A></TD>
END
    if ( $cust_main ) {
      print <<END;
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$custnum</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$last, $first</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$company</A></FONT></TD>
END
      if ( defined dbdef->table('cust_main')->column('ship_last') ) {
        print <<END;
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$ship_last, $ship_first</A></FONT></TD>
      <TD ROWSPAN=$rowspan><FONT SIZE=-1><A HREF="${p}view/cust_main.cgi?$custnum">$ship_company</A></FONT></TD>
END
      }
    } else {
      my $colspan = defined dbdef->table('cust_main')->column('ship_last')
                    ? 5 : 3;
      print <<END;
      <TD ROWSPAN=$rowspan COLSPAN=$colspan>WARNING: couldn't find cust_main.custnum $custnum (cust_pkg.pkgnum $pkgnum)</TD>
END
    }

    my $n2 = '';
    foreach my $cust_svc ( @cust_svc ) {
      my($label, $value, $svcdb) = $cust_svc->label;
      my $svcnum = $cust_svc->svcnum;
      my $sview = $p. "view";
      print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
            qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
      $n2="</TR><TR>";
    }

    $n1 = "</TR><TR>";

  }
    print '</TR>';
 
  print <<END;
    </TABLE>
  </BODY>
</HTML>
END

}

sub pkgnum_sort {
  $a->getfield('pkgnum') <=> $b->getfield('pkgnum');
}

%>
