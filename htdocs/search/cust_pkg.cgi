#!/usr/bin/perl -Tw
#
# $Id: cust_pkg.cgi,v 1.4 1999-01-18 09:22:33 ivan Exp $
#
# based on search/svc_acct.cgi ivan@sisd.com 98-jul-17
#
# $Log: cust_pkg.cgi,v $
# Revision 1.4  1999-01-18 09:22:33  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.3  1998/12/23 03:05:59  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:41:09  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header idiot popurl);

my($cgi)=new CGI;
&cgisuidsetup($cgi);

my(@cust_pkg,$sortby);

my($query)=$cgi->keywords;
#this tree is a little bit redundant
if ( $query eq 'pkgnum' ) {
  $sortby=\*pkgnum_sort;
  @cust_pkg=qsearch('cust_pkg',{});
} elsif ( $query eq 'APKG_pkgnum' ) {
  $sortby=\*pkgnum_sort;

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
  &idiot("No packages found");
  exit;
} else {
  my($total)=scalar(@cust_pkg);
  print $cgi->header, header('Package Search Results',''), <<END;
    $total matching packages found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Package #</TH>
        <TH>Customer #</TH>
        <TH>Name</TH>
        <TH>Company</TH>
      </TR>
END

  my(%saw,$cust_pkg);
  foreach $cust_pkg (
    sort $sortby grep(!$saw{$_->pkgnum}++, @cust_pkg)
  ) {
    my($cust_main)=qsearchs('cust_main',{'custnum'=>$cust_pkg->custnum});
    my($pkgnum,$custnum,$name,$company)=(
      $cust_pkg->pkgnum,
      $cust_main->custnum,
      $cust_main->last. ', '. $cust_main->first,
      $cust_main->company,
    );
    print <<END;
    <TR>
      <TD><A HREF="../view/cust_pkg.cgi?$pkgnum"><FONT SIZE=-1>$pkgnum</FONT></A></TD>
      <TD><FONT SIZE=-1>$custnum</FONT></TD>
      <TD><FONT SIZE=-1>$name</FONT></TD>
      <TD><FONT SIZE=-1>$company</FONT></TD>
    </TR>
END

  }
 
  print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END
  exit;

}

sub pkgnum_sort {
  $a->getfield('pkgnum') <=> $b->getfield('pkgnum');
}

