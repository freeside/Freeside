<%
#<!-- $Id: svc_acct_sm.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $conf $cgi $mydomain $action $svcnum $svc_acct_sm $pkgnum $svcpart
             $part_svc $query %username %domain $p1 $domuser $domsvc $domuid );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct_sm;
use FS::Conf;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

if ( $cgi->param('error') ) {
  $svc_acct_sm = new FS::svc_acct_sm ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct_sm')
  } );
  $svcnum = $svc_acct_sm->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_acct_sm=qsearchs('svc_acct_sm',{'svcnum'=>$svcnum})
      or die "Unknown (svc_acct_sm) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_acct_sm = new FS::svc_acct_sm({});

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
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

  }
}
$action = $svc_acct_sm->svcnum ? 'Edit' : 'Add';

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

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Mail Alias $action", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/svc_acct_sm.cgi" METHOD=POST>!;

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

($domuser,$domsvc,$domuid)=(
  $svc_acct_sm->domuser,
  $svc_acct_sm->domsvc,
  $svc_acct_sm->domuid,
);

#domuser
print qq!\n\nMail to <INPUT TYPE="text" NAME="domuser" VALUE="$domuser"> <I>( * for anything )</I>!;

#domsvc
print qq! \@ <SELECT NAME="domsvc" SIZE=1>!;
foreach $_ (keys %domain) {
  print "<OPTION", $_ eq $domsvc ? " SELECTED" : "",
        qq! VALUE="$_">$domain{$_}!;
}
print "</SELECT>";

#uid
print qq!\nforwards to <SELECT NAME="domuid" SIZE=1>!;
foreach $_ (keys %username) {
  print "<OPTION", ($_ eq $domuid) ? " SELECTED" : "",
        qq! VALUE="$_">$username{$_}!;
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

%>
