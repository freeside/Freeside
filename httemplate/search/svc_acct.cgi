<%
# <!-- $Id: svc_acct.cgi,v 1.3 2001-08-19 15:53:35 jeff Exp $ -->

use strict;
use vars qw( $cgi @svc_acct $sortby $query );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header eidiot popurl table);
use FS::svc_acct;
use FS::cust_main;

$cgi = new CGI;
&cgisuidsetup($cgi);

($query)=$cgi->keywords;
$query ||= ''; #to avoid use of unitialized value errors
#this tree is a little bit redundant
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_acct=qsearch('svc_acct',{});
} elsif ( $query eq 'username' ) {
  $sortby=\*username_sort;
  @svc_acct=qsearch('svc_acct',{});
} elsif ( $query eq 'uid' ) {
  $sortby=\*uid_sort;
  @svc_acct=grep $_->uid ne '', qsearch('svc_acct',{});
} elsif ( $query eq 'UN_svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_acct = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_acct',{});
} elsif ( $query eq 'UN_username' ) {
  $sortby=\*username_sort;
  @svc_acct = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_acct',{});
} elsif ( $query eq 'UN_uid' ) {
  $sortby=\*uid_sort;
  @svc_acct = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_acct',{});
} else {
  $sortby=\*uid_sort;
  &usernamesearch;
}

if ( scalar(@svc_acct) == 1 ) {
  my($svcnum)=$svc_acct[0]->svcnum;
  print $cgi->redirect(popurl(2). "view/svc_acct.cgi?$svcnum");  #redirect
  exit;
} elsif ( scalar(@svc_acct) == 0 ) { #error
  eidiot("Account not found");
} else {
  my($total)=scalar(@svc_acct);
  print $cgi->header( '-expires' => 'now' ),
        header("Account Search Results",''),
        "$total matching accounts found",
        &table(), <<END;
      <TR>
        <TH><FONT SIZE=-1>Service #</FONT></TH>
        <TH><FONT SIZE=-1>Username</FONT></TH>
        <TH><FONT SIZE=-1>Domain</FONT></TH>
        <TH><FONT SIZE=-1>UID</FONT></TH>
        <TH><FONT SIZE=-1>Service</FONT></TH>
        <TH><FONT SIZE=-1>Customer #</FONT></TH>
        <TH><FONT SIZE=-1>Contact name</FONT></TH>
        <TH><FONT SIZE=-1>Company</FONT></TH>
      </TR>
END

  my(%saw,$svc_acct);
  my $p = popurl(2);
  foreach $svc_acct (
    sort $sortby grep(!$saw{$_->svcnum}++, @svc_acct)
  ) {
    my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $svc_acct->svcnum })
      or die "No cust_svc record for svcnum ". $svc_acct->svcnum;
    my $part_svc = qsearchs('part_svc', { 'svcpart' => $cust_svc->svcpart })
      or die "No part_svc record for svcpart ". $cust_svc->svcpart;
    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc })
      or die "No svc_domain record for domsvc ". $cust_svc->domsvc;
    my($cust_pkg,$cust_main);
    if ( $cust_svc->pkgnum ) {
      $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $cust_svc->pkgnum })
        or die "No cust_pkg record for pkgnum ". $cust_svc->pkgnum;
      $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pkg->custnum })
        or die "No cust_main record for custnum ". $cust_pkg->custnum;
    }
    my($svcnum,$username,$domain,$uid,$svc,$custnum,$last,$first,$company)=(
      $svc_acct->svcnum,
      $svc_acct->getfield('username'),
      $svc_domain->getfield('domain'),
      $svc_acct->getfield('uid'),
      $part_svc->svc,
      $cust_svc->pkgnum ? $cust_main->custnum : '',
      $cust_svc->pkgnum ? $cust_main->getfield('last') : '',
      $cust_svc->pkgnum ? $cust_main->getfield('first') : '',
      $cust_svc->pkgnum ? $cust_main->company : '',
    );
    my($pcustnum) = $custnum
      ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\"><FONT SIZE=-1>$custnum</FONT></A>"
      : "<I>(unlinked)</I>"
    ;
    my($pname) = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$last, $first</A>" : '';
    my $pcompany = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$company</A>" : '';
    print <<END;
    <TR>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$svcnum</FONT></A></TD>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$username</FONT></A></TD>
      <TD><FONT SIZE=-1>$domain</FONT></TD>
      <TD><A HREF="${p}view/svc_acct.cgi?$svcnum"><FONT SIZE=-1>$uid</FONT></A></TD>
      <TD><FONT SIZE=-1>$svc</FONT></TH>
      <TD><FONT SIZE=-1>$pcustnum</FONT></TH>
      <TD><FONT SIZE=-1>$pname<FONT></TH>
      <TD><FONT SIZE=-1>$pcompany</FONT></TH>
    </TR>
END

  }
 
  print <<END;
    </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

}

sub svcnum_sort {
  $a->getfield('svcnum') <=> $b->getfield('svcnum');
}

sub username_sort {
  $a->getfield('username') cmp $b->getfield('username');
}

sub uid_sort {
  $a->getfield('uid') <=> $b->getfield('uid');
}

sub usernamesearch {

  $cgi->param('username') =~ /^([\w\d\-]+)$/; #untaint username_text
  my($username)=$1;

  @svc_acct=qsearch('svc_acct',{'username'=>$username});

}


%>
