#!/usr/bin/perl -Tw
#
# $Id: svc_domain.cgi,v 1.9 1999-04-15 13:39:16 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
#
# ivan@voicenet.com 97-mar-5
#
# rewrite ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# display total, use FS::CGI now does browsing too ivan@sisd.com 98-jul-17
#
# $Log: svc_domain.cgi,v $
# Revision 1.9  1999-04-15 13:39:16  ivan
# $cgi->header( '-expires' => 'now' )
#
# Revision 1.8  1999/02/28 00:03:57  ivan
# removed misleading comments
#
# Revision 1.7  1999/02/23 08:09:24  ivan
# beginnings of one-screen new customer entry and some other miscellania
#
# Revision 1.6  1999/02/09 09:22:59  ivan
# visual and bugfixes
#
# Revision 1.5  1999/02/07 09:59:39  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:14:17  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:06:50  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:41:12  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use vars qw ( $cgi @svc_domain $sortby $query $conf $mydomain );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header eidiot popurl);
use FS::svc_domain;
use FS::cust_svc;
use FS::svc_acct_sm;
use FS::svc_acct;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

($query)=$cgi->keywords;
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
  $cgi->param('domain') =~ /^([\w\-\.]+)$/; 
  my($domain)=$1;
  push @svc_domain, qsearchs('svc_domain',{'domain'=>$domain});
}

if ( scalar(@svc_domain) == 1 ) {
  print $cgi->redirect(popurl(2). "view/svc_domain.cgi?". $svc_domain[0]->svcnum);
  exit;
} elsif ( scalar(@svc_domain) == 0 ) {
  eidiot "No matching domains found!\n";
} else {

  my($total)=scalar(@svc_domain);
  print $cgi->header( '-expires' => 'now' ),
        header("Domain Search Results",''), <<END;

    $total matching domains found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH>Domain</TH>
        <TH>Mail to<BR><FONT SIZE=-1>(click to view mail alias)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
      </TR>
END

  my(%saw,$svc_domain);
  my $p = popurl(2);
  foreach $svc_domain (
    sort $sortby grep(!$saw{$_->svcnum}++, @svc_domain)
  ) {
    my($svcnum,$domain)=(
      $svc_domain->svcnum,
      $svc_domain->domain,
    );
    #my($malias);
    #if ( qsearch('svc_acct_sm',{'domsvc'=>$svcnum}) ) {
    #  $malias=(
    #    qq|<FORM ACTION="svc_acct_sm.cgi" METHOD="post">|.
    #      qq|<INPUT TYPE="hidden" NAME="domuser" VALUE="">|.
    #      qq|<INPUT TYPE="hidden" NAME="domain" VALUE="$domain">|.
    #      qq|<INPUT TYPE="submit" VALUE="(mail aliases)">|.
    #      qq|</FORM>|
    #  );
    #} else {
    #  $malias='';
    #}

    my @svc_acct_sm=qsearch('svc_acct_sm',{'domsvc' => $svcnum});
    my $rowspan = scalar(@svc_acct_sm) || 1;

    print <<END;
    <TR>
      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_domain.cgi?$svcnum"><FONT SIZE=-1>$svcnum</FONT></A></TD>
      <TD ROWSPAN=$rowspan>$domain</TD>
END

    my $n1 = '';
    # false laziness: this was stolen from search/svc_acct_sm.cgi.  but the
    # web interface in general needs to be rewritten in a mucho cleaner way
    my($svc_acct_sm);
    foreach $svc_acct_sm (@svc_acct_sm) {
      my($svcnum,$domuser,$domuid,$domsvc)=(
        $svc_acct_sm->svcnum,
        $svc_acct_sm->domuser,
        $svc_acct_sm->domuid,
        $svc_acct_sm->domsvc,
      );
      #my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $domsvc } );
      #if ( $svc_domain ) {
      #  my $domain = $svc_domain->domain;

        print qq!$n1<TD><A HREF="!. popurl(2). qq!view/svc_acct_sm.cgi?$svcnum">!,
        #print '', ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser );
              ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser ),
              qq!\@$domain</A> </TD>!,
        ;
      #} else {
      #  my $warning = "couldn't find svc_domain.svcnum $svcnum ( svc_acct_sm.svcnum $svcnum";
      #  warn $warning;
      #  print "$n1<TD>WARNING: $warning</TD>";
      #}

      my $svc_acct = qsearchs( 'svc_acct', { 'uid' => $domuid } );
      if ( $svc_acct ) {
        my $username = $svc_acct->username;
        my $svc_acct_svcnum =$svc_acct->svcnum;
        print qq!<TD><A HREF="!, popurl(2),
              qq!view/svc_acct.cgi?$svc_acct_svcnum">$username\@$mydomain</A>!,
              qq!</TD></TR>!
        ;
      } else {
        my $warning = "couldn't find svc_acct.uid $domuid (svc_acct_sm.svcnum $svcnum)!";
        warn $warning;
        print "<TD>WARNING: $warning</TD>";
      }
      $n1 = "</TR><TR>";
    }
    #end of false laziness
    print "</TR>";

  }
 
  print <<END;
    </TABLE>
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


