#!/usr/bin/perl -Tw
#
# $Id: svc_acct_sm.cgi,v 1.7 1999-02-28 00:03:56 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
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
#
# $Log: svc_acct_sm.cgi,v $
# Revision 1.7  1999-02-28 00:03:56  ivan
# removed misleading comments
#
# Revision 1.6  1999/02/09 09:22:58  ivan
# visual and bugfixes
#
# Revision 1.5  1999/01/19 05:14:16  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:40  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 09:41:11  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use vars qw( $conf $cgi $mydomain $domuser $svc_domain $domsvc @svc_acct_sm );
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl idiot header table);
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use FS::svc_domain;
use FS::svc_acct_sm;
use FS::svc_acct;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

$cgi->param('domuser') =~ /^([a-z0-9_\-]{0,32})$/;
$domuser = $1;

$cgi->param('domain') =~ /^([\w\-\.]+)$/ or die "Illegal domain";
$svc_domain = qsearchs('svc_domain',{'domain'=>$1})
  or die "Unknown domain";
$domsvc = $svc_domain->svcnum;

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
  print $cgi->redirect(popurl(2). "view/svc_acct_sm.cgi?$svcnum");
} elsif ( scalar(@svc_acct_sm) > 1 ) {
  print $cgi->header( '-expires' => 'now' ),
        header('Mail Alias Search Results'),
        table, <<END;
      <TR>
        <TH>Mail to<BR><FONT SIZE=-1>(click to view mail alias)</FONT></TH>
        <TH>Forwards to<BR><FONT SIZE=-1>(click to view account)</FONT></TH>
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

    my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $domsvc } );
    if ( $svc_domain ) {
      my $domain = $svc_domain->domain;

      print qq!<TR><TD><A HREF="!. popurl(2). qq!view/svc_acct_sm.cgi?$svcnum">!,
      #print '', ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser );
            ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser ),
            qq!\@$domain</A> </TD>!,
      ;
    } else {
      my $warning = "couldn't find svc_domain.svcnum $svcnum ( svc_acct_sm.svcnum $svcnum";
      warn $warning;
      print "<TR><TD>WARNING: $warning</TD>";
    }

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
      print "<TD>WARNING: $warning</TD></TR>";
    }

  }

  print '</TABLE></BODY></HTML>';

} else { #error
  idiot("Mail Alias not found");
}

