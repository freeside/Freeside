#!/usr/bin/perl -Tw
#
# svc_acct_sm.cgi: Search for domains (process form)
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 96-mar-5
#
# need to look at table in results to make it more readable
#
# ivan@voicenet.com
#
# rewrite ivan@sisd.com 98-mar-15
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);

my($conf_domain)="/var/spool/freeside/conf/domain";
open(DOMAIN,$conf_domain) or die "Can't open $conf_domain: $!";
my($mydomain)=map {
  /^(.*)$/ or die "Illegal line in $conf_domain!"; #yes, we trust the file
  $1
} grep $_ !~ /^(#|$)/, <DOMAIN>;
close DOMAIN;

my($req)=new CGI::Request; # create form object
&cgisuidsetup($req->cgi);

$req->param('domuser') =~ /^([a-z0-9_\-]{0,32})$/;
my($domuser)=$1;

$req->param('domain') =~ /^([\w\-\.]+)$/ or die "Illegal domain";
my($svc_domain)=qsearchs('svc_domain',{'domain'=>$1})
  or die "Unknown domain";
my($domsvc)=$svc_domain->svcnum;

my(@svc_acct_sm);
if ($domuser) {
  @svc_acct_sm=qsearch('svc_acct_sm',{
    'domuser' => $domuser,
    'domsvc'  => $domsvc,
  });
} else {
  @svc_acct_sm=qsearch('svc_acct_sm',{'domsvc' => $domsvc});
}

if ( scalar(@svc_acct_sm) == 1 ) {
  my($svcnum)=$svc_acct_sm[0]->svcnum;
  $req->cgi->redirect("../view/svc_acct_sm.cgi?$svcnum");  #redirect
} elsif ( scalar(@svc_acct_sm) > 1 ) {
  CGI::Base::SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Mail Alias Search Results</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Mail Alias Search Results</H4>
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Mail to<BR><FONT SIZE=-2>(click here to view mail alias)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-2>(click here to view account)</FONT></TH>
      </TR>
END

  my($svc_acct_sm);
  foreach $svc_acct_sm (@svc_acct_sm) {
    my($svcnum,$domuser,$domuid,$domsvc)=(
      $svc_acct_sm->svcnum,
      $svc_acct_sm->domuser,
      $svc_acct_sm->domuid,
      $svc_acct_sm->domsvc,
    );
    my($svc_domain)=qsearchs('svc_domain',{'svcnum'=>$domsvc});
    my($domain)=$svc_domain->domain;
    my($svc_acct)=qsearchs('svc_acct',{'uid'=>$domuid});
    my($username)=$svc_acct->username;
    my($svc_acct_svcnum)=$svc_acct->svcnum;

    print <<END;
<TR>\n        <TD> <A HREF="../view/svc_acct_sm.cgi?$svcnum">
END

    print '', ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser );

    print <<END;
\@$domain</A> </TD>\n
<TD> <A HREF="../view/svc_acct.cgi?$svc_acct_svcnum">$username\@$mydomain</A> </TD>\n      </TR>\n
END

  }

  print <<END;
      </TABLE>
    </CENTER>
  </BODY>
</HTML>
END

} else { #error
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Mail Alias Search Error</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H3>Mail Alias Search Error</H3>
    <HR>
    Mail Alias not found.
    </CENTER>
  </BODY>
</HTML>
END

}

