#!/usr/bin/perl -Tw
#
# $Id: svc_acct.cgi,v 1.8 1999-02-23 08:09:22 ivan Exp $
#
# Usage: svc_acct.cgi {svcnum} | pkgnum{pkgnum}-svcpart{svcpart}
#        http://server.name/path/svc_acct.cgi? {svcnum} | pkgnum{pkgnum}-svcpart{svcpart}
#
# Note: Should be run setuid freeside as user nobody
#
# ivan@voicenet.com 96-dec-18
#
# rewrite ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
# Changed 'password' to '_password' because Pg6.3 reserves the password word
#       bmccane@maxbaud.net     98-apr-3
#
# use conf/shells and dbdef username length ivan@sisd.com 98-jul-13
#
# $Log: svc_acct.cgi,v $
# Revision 1.8  1999-02-23 08:09:22  ivan
# beginnings of one-screen new customer entry and some other miscellania
#
# Revision 1.7  1999/02/07 09:59:22  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.6  1999/01/19 05:13:43  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 09:41:32  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/30 23:03:22  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.3  1998/12/17 06:17:08  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use vars qw( $conf $cgi @shells $action $svcnum $svc_acct $pkgnum $svcpart
             $part_svc $svc $otaker $username $password $ulen $ulen2 $p1
             $popnum $uid $gid $finger $dir $shell $quota $slipip );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct;
use FS::Conf;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
@shells = $conf->config('shells');

if ( $cgi->param('error') ) {
  $svc_acct = new FS::svc_acct ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct')
  } );
  $svcnum = $svc_acct->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_acct=qsearchs('svc_acct',{'svcnum'=>$svcnum})
      or die "Unknown (svc_acct) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;

    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_acct = new FS::svc_acct({}); 

    foreach $_ (split(/-/,$query)) {
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svcnum='';

    #set gecos
    my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
    if ($cust_pkg) {
      my($cust_main)=qsearchs('cust_main',{'custnum'=> $cust_pkg->custnum } );
      $svc_acct->setfield('finger',
        $cust_main->getfield('first') . " " . $cust_main->getfield('last')
      ) ;
    }

    #set fixed and default fields from part_svc
    my($field);
    foreach $field ( fields('svc_acct') ) {
      if ( $part_svc->getfield('svc_acct__'. $field. '_flag') ne '' ) {
        $svc_acct->setfield($field,$part_svc->getfield('svc_acct__'. $field) );
      }
    }

  }
}
$action = $svcnum ? 'Edit' : 'Add';

$svc = $part_svc->getfield('svc');

$otaker = getotaker;

($username,$password)=(
  $svc_acct->username,
  $svc_acct->_password ? "*HIDDEN*" : '',
);

$ulen = $svc_acct->dbdef_table->column('username')->length;
$ulen2 = $ulen+2;

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("$action $svc account");

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END;
    <FORM ACTION="${p1}process/svc_acct.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
Username: 
<INPUT TYPE="text" NAME="username" VALUE="$username" SIZE=$ulen2 MAXLENGTH=$ulen>
<BR>Password: 
<INPUT TYPE="text" NAME="_password" VALUE="$password" SIZE=10 MAXLENGTH=8> 
(blank to generate)
END

#pop
$popnum = $svc_acct->popnum || 0;
if ( $part_svc->svc_acct__popnum_flag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$popnum">!;
} else { 
  print qq!<BR>POP: <SELECT NAME="popnum" SIZE=1><OPTION>\n!;
  my($svc_acct_pop);
  foreach $svc_acct_pop ( qsearch ('svc_acct_pop',{} ) ) {
  print "<OPTION", $svc_acct_pop->popnum == $popnum ? ' SELECTED' : '', ">", 
        $svc_acct_pop->popnum, ": ", 
        $svc_acct_pop->city, ", ",
        $svc_acct_pop->state,
        " (", $svc_acct_pop->ac, ")/",
        $svc_acct_pop->exch, "\n"
      ;
  }
  print "</SELECT>";
}

($uid,$gid,$finger,$dir)=(
  $svc_acct->uid,
  $svc_acct->gid,
  $svc_acct->finger,
  $svc_acct->dir,
);

print <<END;
<INPUT TYPE="hidden" NAME="uid" VALUE="$uid">
<INPUT TYPE="hidden" NAME="gid" VALUE="$gid">
<BR>GECOS: <INPUT TYPE="text" NAME="finger" VALUE="$finger">
<INPUT TYPE="hidden" NAME="dir" VALUE="$dir">
END

$shell = $svc_acct->shell;
if ( $part_svc->svc_acct__shell_flag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="shell" VALUE="$shell">!;
} else {
  print qq!<BR>Shell: <SELECT NAME="shell" SIZE=1>!;
  my($etc_shell);
  foreach $etc_shell (@shells) {
    print "<OPTION", $etc_shell eq $shell ? ' SELECTED' : '', ">",
          $etc_shell, "\n";
  }
  print "</SELECT>";
}

($quota,$slipip)=(
  $svc_acct->quota,
  $svc_acct->slipip,
);

print qq!<INPUT TYPE="hidden" NAME="quota" VALUE="$quota">!;

if ( $part_svc->svc_acct__slipip_flag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="slipip" VALUE="$slipip">!;
} else {
  print qq!<BR>IP: <INPUT TYPE="text" NAME="slipip" VALUE="$slipip">!;
}

#submit
print qq!<P><CENTER><INPUT TYPE="submit" VALUE="Submit"></CENTER>!; 

print <<END;
    </FORM>
  </BODY>
</HTML>
END


