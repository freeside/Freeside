#!/usr/bin/perl -Tw
#
# svc_acct_sm.cgi: Add/edit a mail alias (output form)
#
# Usage: svc_acct_sm.cgi {svcnum} | pkgnum{pkgnum}-svcpart{svcpart}
#        http://server.name/path/svc_acct_sm.cgi? {svcnum} | pkgnum{pkgnum}-svcpart{svcpart}
#
# use {svcnum} for edit, pkgnum{pkgnum}-svcpart{svcpart} for add
#
# Note: Should be run setuid freeside as user nobody.
#
# should error out in a more CGI-friendly way, and should have more error checking (sigh).
#
# ivan@voicenet.com 97-jan-5
#
# added debugging code; fixed CPU-sucking problem with trying to edit an (unaudited) mail alias (no pkgnum)
#
# ivan@voicenet.com 97-may-7
#
# fixed uid selection
# ivan@voicenet.com 97-jun-4
#
# uid selection across _CUSTOMER_, not just _PACKAGE_
#
# ( i need to be rewritten with fast searches)
#
# ivan@voicenet.com 97-oct-3
#
# added fast searches in some of the places where it is sorely needed...
# I see DBI::mysql in your future...
# ivan@voicenet.com 97-oct-23
#
# rewrite ivan@sisd.com 98-mar-15
#
# /var/spool/freeside/conf/domain ivan@sisd.com 98-jul-26

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::svc_acct_sm qw(fields);

my($conf_domain)="/var/spool/freeside/conf/domain";
open(DOMAIN,$conf_domain) or die "Can't open $conf_domain: $!";
my($mydomain)=map {
  /^(.*)$/ or die "Illegal line in $conf_domain!"; #yes, we trust the file
  $1
} grep $_ !~ /^(#|$)/, <DOMAIN>;
close DOMAIN;

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);

SendHeaders(); # one guess.

my($action,$svcnum,$svc_acct_sm,$pkgnum,$svcpart,$part_svc);
if ( $QUERY_STRING =~ /^(\d+)$/ ) { #editing

  $svcnum=$1;
  $svc_acct_sm=qsearchs('svc_acct_sm',{'svcnum'=>$svcnum})
    or die "Unknown (svc_acct_sm) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;
  
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $action="Edit";

} else { #adding

  $svc_acct_sm=create FS::svc_acct_sm({});

  foreach $_ (split(/-/,$QUERY_STRING)) { #get & untaint pkgnum & svcpart
    $pkgnum=$1 if /^pkgnum(\d+)$/;
    $svcpart=$1 if /^svcpart(\d+)$/;
  }
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svcnum='';

  #set fixed and default fields from part_svc
  my($field);
  foreach $field ( fields('svc_acct_sm') ) {
    if ( $part_svc->getfield('svc_acct_sm__'. $field. '_flag') ne '' ) {
      $svc_acct_sm->setfield($field,$part_svc->getfield('svc_acct_sm__'. $field) );
    }
  }

  $action='Add';

}

my(%username,%domain);
if ($pkgnum) {

  #find all possible uids (and usernames)

  my($u_part_svc,@u_acct_svcparts);
  foreach $u_part_svc ( qsearch('part_svc',{'svcdb'=>'svc_acct'}) ) {
    push @u_acct_svcparts,$u_part_svc->getfield('svcpart');
  }

  my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  my($custnum)=$cust_pkg->getfield('custnum');
  my($i_cust_pkg);
  foreach $i_cust_pkg ( qsearch('cust_pkg',{'custnum'=>$custnum}) ) {
    my($cust_pkgnum)=$i_cust_pkg->getfield('pkgnum');
    my($acct_svcpart);
    foreach $acct_svcpart (@u_acct_svcparts) {   #now find the corresponding 
                                              #record(s) in cust_svc ( for this
                                              #pkgnum ! )
      my($i_cust_svc);
      foreach $i_cust_svc ( qsearch('cust_svc',{'pkgnum'=>$cust_pkgnum,'svcpart'=>$acct_svcpart}) ) {
        my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$i_cust_svc->getfield('svcnum')});
        $username{$svc_acct->getfield('uid')}=$svc_acct->getfield('username');
      }  
    }
  }

  #find all possible domains (and domsvc's)

  my($d_part_svc,@d_acct_svcparts);
  foreach $d_part_svc ( qsearch('part_svc',{'svcdb'=>'svc_domain'}) ) {
    push @d_acct_svcparts,$d_part_svc->getfield('svcpart');
  }

  foreach $i_cust_pkg ( qsearch('cust_pkg',{'custnum'=>$custnum}) ) {
    my($cust_pkgnum)=$i_cust_pkg->getfield('pkgnum');
    my($acct_svcpart);
    foreach $acct_svcpart (@d_acct_svcparts) {
      my($i_cust_svc);
      foreach $i_cust_svc ( qsearch('cust_svc',{'pkgnum'=>$cust_pkgnum,'svcpart'=>$acct_svcpart}) ) {
        my($svc_domain)=qsearch('svc_domain',{'svcnum'=>$i_cust_svc->getfield('svcnum')});
        $domain{$svc_domain->getfield('svcnum')}=$svc_domain->getfield('domain');
      }
    }
  }

} elsif ( $action eq 'Edit' ) {

  my($svc_acct)=qsearchs('svc_acct',{'uid'=>$svc_acct_sm->domuid});
  $username{$svc_acct_sm->uid} = $svc_acct->username;

  my($svc_domain)=qsearchs('svc_domain',{'svcnum'=>$svc_acct_sm->domsvc});
  $domain{$svc_acct_sm->domsvc} = $svc_domain->domain;

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

print <<END;
<HTML>
  <HEAD>
    <TITLE>Mail Alias $action</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Mail Alias $action</H1>
    </CENTER>
    <FORM ACTION="process/svc_acct_sm.cgi" METHOD=POST>
END

#display

	#formatting
	print "<PRE>";

#svcnum
print qq!<INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">!;
print qq!Service #<FONT SIZE=+1><B>!, $svcnum ? $svcnum : " (NEW)", "</B></FONT>";

#pkgnum
print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!;
 
#svcpart
print qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">!;

my($domuser,$domsvc,$domuid)=(
  $svc_acct_sm->domuser,
  $svc_acct_sm->domsvc,
  $svc_acct_sm->domuid,
);

#domuser
print qq!\n\nMail to <INPUT TYPE="text" NAME="domuser" VALUE="$domuser"> <I>( * for anything )</I>!;

#domsvc
print qq! \@ <SELECT NAME="domsvc" SIZE=1>!;
foreach $_ (keys %domain) {
  print "<OPTION", $_ eq $domsvc ? " SELECTED" : "", ">$_: $domain{$_}";
}
print "</SELECT>";

#uid
print qq!\nforwards to <SELECT NAME="domuid" SIZE=1>!;
foreach $_ (keys %username) {
  print "<OPTION", ($_ eq $domuid) ? " SELECTED" : "", ">$_: $username{$_}";
}
print "</SELECT>\@$mydomain mailbox.";

	#formatting
	print "</PRE>\n";

print qq!<CENTER><INPUT TYPE="submit" VALUE="Submit"></CENTER>!;

print <<END;

    </FORM>
  </BODY>
</HTML>
END

