#!/usr/bin/perl -Tw
#
# svc_domain.cgi: Search for domains (process form)
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 97-mar-5
#
# rewrite ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# display total, use FS::CGI now does browsing too ivan@sisd.com 98-jul-17

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header idiot);

my($req)=new CGI::Request;
&cgisuidsetup($req->cgi);

my(@svc_domain);
my($sortby);

my($query)=$req->cgi->var('QUERY_STRING');
if ( $query eq 'svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'domain' ) {
  $sortby=\*domain_sort;
  @svc_domain=qsearch('svc_domain',{});
} elsif ( $query eq 'UN_svcnum' ) {
  $sortby=\*svcnum_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} elsif ( $query eq 'UN_domain' ) {
  $sortby=\*domain_sort;
  @svc_domain = grep qsearchs('cust_svc',{
      'svcnum' => $_->svcnum,
      'pkgnum' => '',
    }), qsearch('svc_domain',{});
} else {
  $req->param('domain') =~ /^([\w\-\.]+)$/; 
  my($domain)=$1;
  push @svc_domain, qsearchs('svc_domain',{'domain'=>$domain});
}

if ( scalar(@svc_domain) == 1 ) {
  $req->cgi->redirect("../view/svc_domain.cgi?". $svc_domain[0]->svcnum);
  exit;
} elsif ( scalar(@svc_domain) == 0 ) {
  idiot "No matching domains found!\n";
  exit;
} else {
  CGI::Base::SendHeaders(); # one guess

  my($total)=scalar(@svc_domain);
  CGI::Base::SendHeaders(); # one guess
  print header("Domain Search Results",''), <<END;

    $total matching domains found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH>Domain</TH>
        <TH></TH>
      </TR>
END

  my($lines)=16;
  my($lcount)=$lines;
  my(%saw,$svc_domain);
  foreach $svc_domain (
    sort $sortby grep(!$saw{$_->svcnum}++, @svc_domain)
  ) {
    my($svcnum,$domain)=(
      $svc_domain->svcnum,
      $svc_domain->domain,
    );
    my($malias);
    if ( qsearch('svc_acct_sm',{'domsvc'=>$svcnum}) ) {
      $malias=(
        qq|<FORM ACTION="svc_acct_sm.cgi" METHOD="post">|.
          qq|<INPUT TYPE="hidden" NAME="domuser" VALUE="">|.
          qq|<INPUT TYPE="hidden" NAME="domain" VALUE="$domain">|.
          qq|<INPUT TYPE="submit" VALUE="(mail aliases)">|.
          qq|</FORM>|
      );
    } else {
      $malias='';
    }
    print <<END;
    <TR>
      <TD><A HREF="../view/svc_domain.cgi?$svcnum"><FONT SIZE=-1>$svcnum</FONT></A></TD>
      <TD><FONT SIZE=-1>$domain</FONT></TD>
      <TD><FONT SIZE=-1>$malias</FONT></TD>
    </TR>
END
    if ($lcount-- == 0) { # lots of little tables instead of one big one
      $lcount=$lines;
      print <<END;   
  </TABLE>
  <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
    <TR>
      <TH>Service #</TH>
      <TH>Domain</TH>
      <TH></TH>
    </TR>
END
    }
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

sub domain_sort {
  $a->getfield('domain') cmp $b->getfield('doimain');
}


