<%
# <!-- $Id: svc_acct.cgi,v 1.4 2001-08-21 02:16:36 ivan Exp $ -->

use strict;
use vars qw( $cgi @svc_acct $sortby $query $mydomain );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs dbdef);
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
        <TH><FONT SIZE=-1>#</FONT></TH>
        <TH><FONT SIZE=-1>Username</FONT></TH>
        <TH><FONT SIZE=-1>Domain</FONT></TH>
        <TH><FONT SIZE=-1>UID</FONT></TH>
        <TH><FONT SIZE=-1>Service</FONT></TH>
        <TH><FONT SIZE=-1>Cust#</FONT></TH>
        <TH><FONT SIZE=-1>(bill) name</FONT></TH>
        <TH><FONT SIZE=-1>company</FONT></TH>
END
  if ( defined dbdef->table('cust_main')->column('ship_last') ) {
    print <<END;
        <TH><FONT SIZE=-1>(service) name</FONT></TH>
        <TH><FONT SIZE=-1>company</FONT></TH>
END
  }
  print "</TR>";

  my(%saw,$svc_acct);
  my $p = popurl(2);
  foreach $svc_acct (
    sort $sortby grep(!$saw{$_->svcnum}++, @svc_acct)
  ) {
    my $cust_svc = qsearchs('cust_svc', { 'svcnum' => $svc_acct->svcnum })
      or die "No cust_svc record for svcnum ". $svc_acct->svcnum;
    my $part_svc = qsearchs('part_svc', { 'svcpart' => $cust_svc->svcpart })
      or die "No part_svc record for svcpart ". $cust_svc->svcpart;

    my $domain;
    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc });
    if ( $svc_domain ) {
      $domain = "<A HREF=\"${p}view/svc_domain.cgi?". $svc_domain->svcnum.
                "\">". $svc_domain->domain. "</A>";
    } else {
      unless ( $mydomain ) {
        my $conf = new FS::Conf;
        unless ( $mydomain = $conf->config('domain') ) {
          die "No legacy domain config file and no svc_domain.svcnum record ".
              "for svc_acct.domsvc: ". $cust_svc->domsvc;
        }
      }
      $domain = "<i>$mydomain</i><FONT COLOR=\"#FF0000\">*</FONT>";
    }
    my($cust_pkg,$cust_main);
    if ( $cust_svc->pkgnum ) {
      $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $cust_svc->pkgnum })
        or die "No cust_pkg record for pkgnum ". $cust_svc->pkgnum;
      $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pkg->custnum })
        or die "No cust_main record for custnum ". $cust_pkg->custnum;
    }
    my($svcnum, $username, $uid, $svc, $custnum, $last, $first, $company) = (
      $svc_acct->svcnum,
      $svc_acct->getfield('username'),
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
    my $pname = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$last, $first</A>" : '';
    my $pcompany = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$company</A>" : '';
    my($pship_name, $pship_company);
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      my($ship_last, $ship_first, $ship_company) = (
        $cust_svc->pkgnum ? ( $cust_main->ship_last || $last ) : '',
        $cust_svc->pkgnum ? ( $cust_main->ship_last
                              ? $cust_main->ship_first
                              : $first
                            ) : '',
        $cust_svc->pkgnum ? ( $cust_main->ship_last
                              ? $cust_main->ship_company
                              : $company
                            ) : '',
      );
      $pship_name = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$ship_last, $ship_first</A>" : '';
      $pship_company = $custnum ? "<A HREF=\"${p}view/cust_main.cgi?$custnum\">$ship_company</A>" : '';
    }
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
END
    if ( defined dbdef->table('cust_main')->column('ship_last') ) {
      print <<END;
      <TD><FONT SIZE=-1>$pship_name<FONT></TH>
      <TD><FONT SIZE=-1>$pship_company</FONT></TH>
END
    }
    print "</TR>";

  }
 
  print '</TABLE>';

  if ( $mydomain ) {
    print "<BR><FONT COLOR=\"#FF0000\">*</FONT> The <I>$mydomain</I> domain ".
          "is contained in your legacy <CODE>domain</CODE> ".
          "<A HREF=\"${p}docs/config.html#domain\">configuration file</A>.  ".
          "You should run the <CODE>bin/fs-migrate-svc_acct_sm</CODE> script ".
          "to create a proper svc_domain record for this domain."
  }

  print '</BODY></HTML>';

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
