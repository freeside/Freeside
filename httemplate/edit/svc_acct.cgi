<%
#<!-- $Id: svc_acct.cgi,v 1.10 2001-10-20 12:18:00 ivan Exp $ -->

use strict;
use vars qw( $conf $cgi @shells $action $svcnum $svc_acct $pkgnum $svcpart
             $part_svc $svc $otaker $username $password $ulen $ulen2 $p1
             $popnum $domsvc $uid $gid $finger $dir $shell $quota $slipip
             %svc_domain );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(header popurl itable);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_acct;
use FS::svc_acct_pop qw(popselector);
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
      "</FONT><BR><BR>"
  if $cgi->param('error');

print 'Service # '. ( $svcnum ? "<B>$svcnum</B>" : " (NEW)" ). '<BR>'.
      'Service: <B>'. $part_svc->svc. '</B><BR><BR>'.
      <<END;
    <FORM ACTION="${p1}process/svc_acct.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
END

print &itable("#cccccc",2), <<END;
<TR><TD>
<TR><TD ALIGN="right">Username</TD>
<TD><INPUT TYPE="text" NAME="username" VALUE="$username" SIZE=$ulen2 MAXLENGTH=$ulen></TD></TR>
<TR><TD ALIGN="right">Password</TD>
<TD><INPUT TYPE="text" NAME="_password" VALUE="$password" SIZE=10 MAXLENGTH=8>
(blank to generate)</TD>
</TR>
END

#domain
$domsvc = $svc_acct->domsvc || 0;
if ( $part_svc->part_svc_column('domsvc')->columnflag eq 'F' ) {
  print qq!<INPUT TYPE="hidden" NAME="domsvc" VALUE="$domsvc">!;
} else { 
  my %svc_domain = ();

  if ( $domsvc ) {
    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $domsvc, } );
    if ( $svc_domain ) {
      $svc_domain{$svc_domain->svcnum} = $svc_domain;
    } else {
      warn "unknown svc_domain.svcnum for svc_acct.domsvc: $domsvc";
    }
  }

  if ( $part_svc->part_svc_column('domsvc')->columnflag eq 'D' ) {
    my $svc_domain = qsearchs('svc_domain', {
      'svcnum' => $part_svc->part_svc_column('domsvc')->columnvalue,
    } );
    if ( $svc_domain ) {
      $svc_domain{$svc_domain->svcnum} = $svc_domain;
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
     $svc_domain{$svc_domain->svcnum} = $svc_domain if $svc_domain;
    }
  } else {
    %svc_domain = map { $_->svcnum => $_ } qsearch('svc_domain', {} );
  }
  print qq!<TR><TD ALIGN="right">Domain</TD>!.
        qq!<TD><SELECT NAME="domsvc" SIZE=1>\n!;
  foreach my $svcnum (
    sort { $svc_domain{$a}->domain cmp $svc_domain{$b}->domain }
      keys %svc_domain
  ) {
    my $svc_domain = $svc_domain{$svcnum};
    print qq!<OPTION VALUE="!. $svc_domain->svcnum. qq!"!.
          ( $svc_domain->svcnum == $domsvc ? ' SELECTED' : '' ).
          '>'. $svc_domain->domain. "\n" ;
  }
  print "</SELECT></TD></TR>";
}

#pop
$popnum = $svc_acct->popnum || 0;
if ( $part_svc->part_svc_column('popnum')->columnflag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$popnum">!;
} else { 
  print qq!<TR><TD ALIGN="right">Access number</TD>!.
        qq!<TD>!. FS::svc_acct_pop::popselector($popnum). '</TD></TR>';
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
<TR><TD ALIGN="right">GECOS</TD><TD><INPUT TYPE="text" NAME="finger" VALUE="$finger"></TD></TR>
<INPUT TYPE="hidden" NAME="dir" VALUE="$dir">
END

$shell = $svc_acct->shell;
if ( $part_svc->part_svc_column('shell')->columnflag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="shell" VALUE="$shell">!;
} else {
  print qq!<TR><TD ALIGN="right">Shell</TD><TD><SELECT NAME="shell" SIZE=1>!;
  my($etc_shell);
  foreach $etc_shell (@shells) {
    print "<OPTION", $etc_shell eq $shell ? ' SELECTED' : '', ">",
          $etc_shell, "\n";
  }
  print "</SELECT></TD></TR>";
}

($quota,$slipip)=(
  $svc_acct->quota,
  $svc_acct->slipip,
);

print qq!<INPUT TYPE="hidden" NAME="quota" VALUE="$quota">!;

if ( $part_svc->part_svc_column('slipip')->columnflag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="slipip" VALUE="$slipip">!;
} else {
  print qq!<TR><TD ALIGN="right">IP</TD><TD><INPUT TYPE="text" NAME="slipip" VALUE="$slipip"></TD></TR>!;
}

foreach my $r ( grep { /^r(adius|[cr])_/ } fields('svc_acct') ) {
  $r =~ /^^r(adius|[cr])_(.+)$/ or next; #?
  my $a = $2;
  if ( $part_svc->part_svc_column($r)->columnflag eq 'F' ) {
    print qq!<INPUT TYPE="hidden" NAME="$r" VALUE="!.
          $svc_acct->getfield($r). '">';
  } else {
    print qq!<TR><TD ALIGN="right">$FS::raddb::attrib{$a}</TD><TD><INPUT TYPE="text" NAME="$r" VALUE="!.
          $svc_acct->getfield($r). '"></TD></TR>';
  }
}

#submit
print qq!</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">!; 

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
