<%
#<!-- $Id: svc_acct.cgi,v 1.7 2001-09-11 23:44:01 ivan Exp $ -->

use strict;
use vars qw( $conf $cgi @shells $action $svcnum $svc_acct $pkgnum $svcpart
             $part_svc $svc $otaker $username $password $ulen $ulen2 $p1
             $popnum $domsvc $uid $gid $finger $dir $shell $quota $slipip
             @svc_domain );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct;
use FS::Conf;
use FS::raddb;

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
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_acct->setfield( $part_svc_column->columnname,
                           $part_svc_column->columnvalue,
                         );
    }

  }
}
$action = $svcnum ? 'Edit' : 'Add';

$svc = $part_svc->getfield('svc');

$otaker = getotaker;

$username = $svc_acct->username;
if ( $svc_acct->_password ) {
  if ( $conf->exists('showpasswords') ) {
    $password = $svc_acct->_password;
  } else {
    $password = "*HIDDEN*";
  }
} else {
  $password = '';
}

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

#domain
$domsvc = $svc_acct->domsvc || 0;
if ( $part_svc->part_svc_column('domsvc')->columnflag eq 'F' ) {
  print qq!<INPUT TYPE="hidden" NAME="domsvc" VALUE="$domsvc">!;
} else { 
  my @svc_domain = ();
  if ( $part_svc->part_svc_column('domsvc')->columnflag eq 'D' ) {
    my $svc_domain = qsearchs('svc_domain', {
      'svcnum' => $part_svc->part_svc_column('domsvc')->columnvalue,
    } );
    if ( $svc_domain ) {
      push @svc_domain, $svc_domain;
    } else {
      warn "unknown svc_domain.svcnum for part_svc_column domsvc: ".
           $part_svc->part_svc_column('domsvc')->columnvalue;
    }
  }
  my $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $pkgnum } );
  if ($cust_pkg) {
    my @cust_svc =
      map { qsearch('cust_svc', { 'pkgnum' => $_->pkgnum } ) }
          qsearch('cust_pkg', { 'custnum' => $cust_pkg->custnum } );
    foreach my $cust_svc ( @cust_svc ) {
      my $svc_domain =
        qsearchs('svc_domain', { 'svcnum' => $cust_svc->svcnum } );
      push @svc_domain, $svc_domain if $svc_domain;
    }
  } else {
    @svc_domain = qsearch('svc_domain', {} );
  }
  print qq!<BR>Domain: <SELECT NAME="domsvc" SIZE=1>\n!;
  foreach my $svc_domain ( sort { $a->domain cmp $b->domain } @svc_domain ) {
    print qq!<OPTION VALUE="!, $svc_domain->svcnum, qq!"!,
          $svc_domain->svcnum == $domsvc ? ' SELECTED' : '',
          ">", $svc_domain->domain, "\n"
      ;
  }
  print "</SELECT>";
}

#pop
$popnum = $svc_acct->popnum || 0;
if ( $part_svc->part_svc_column('popnum')->columnflag eq "F" ) {
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
if ( $part_svc->part_svc_column('shell')->columnflag eq "F" ) {
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

if ( $part_svc->part_svc_column('slipip')->columnflag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="slipip" VALUE="$slipip">!;
} else {
  print qq!<BR>IP: <INPUT TYPE="text" NAME="slipip" VALUE="$slipip">!;
}

foreach my $r ( grep { /^r(adius|[cr])_/ } fields('svc_acct') ) {
  $r =~ /^^r(adius|[cr])_(.+)$/ or next; #?
  my $a = $2;
  if ( $part_svc->part_svc_column($r)->columnflag eq 'F' ) {
    print qq!<INPUT TYPE="hidden" NAME="$r" VALUE="!.
          $svc_acct->getfield($r). '">';
  } else {
    print qq!<BR>$FS::raddb::attrib{$a}: <INPUT TYPE="text" NAME="$r" VALUE="!.
          $svc_acct->getfield($r). '">';
  }
}

#submit
print qq!<P><INPUT TYPE="submit" VALUE="Submit">!; 

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
