<!-- mason kludge -->
<%

my $conf = new FS::Conf;
my @shells = $conf->config('shells');

my($svcnum, $pkgnum, $svcpart, $part_svc, $svc_acct, @groups);
if ( $cgi->param('error') ) {
  $svc_acct = new FS::svc_acct ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct')
  } );
  $svcnum = $svc_acct->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry for svcpart $svcpart!" unless $part_svc;
  @groups = $cgi->param('radius_usergroup');
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

    $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
    die "No part_svc entry for svcpart $svcpart!" unless $part_svc;

    @groups = $svc_acct->radius_groups;

  } else { #adding

    $svc_acct = new FS::svc_acct({}); 

    foreach $_ (split(/-/,$query)) {
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
    die "No part_svc entry for svcpart $svcpart!" unless $part_svc;

    $svcnum='';

    #set gecos
    my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
    if ($cust_pkg) {
      my($cust_main)=qsearchs('cust_main',{'custnum'=> $cust_pkg->custnum } );
      unless ( $part_svc->part_svc_column('uid')->columnflag eq 'F' ) {
        $svc_acct->setfield('finger',
          $cust_main->getfield('first') . " " . $cust_main->getfield('last')
        );
      }
    }

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      if ( $part_svc_column->columnname eq 'usergroup' ) {
        @groups = split(',', $part_svc_column->columnvalue);
      } else {
        $svc_acct->setfield( $part_svc_column->columnname,
                             $part_svc_column->columnvalue,
                           );
      }
    }

  }
}

#fixed radius groups always override & display
if ( $part_svc->part_svc_column('usergroup')->columnflag eq "F" ) {
  @groups = split(',', $part_svc->part_svc_column('usergroup')->columnvalue);
}

my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

my $otaker = getotaker;

my $username = $svc_acct->username;
my $password;
if ( $svc_acct->_password ) {
  if ( $conf->exists('showpasswords') || ! $svcnum ) {
    $password = $svc_acct->_password;
  } else {
    $password = "*HIDDEN*";
  }
} else {
  $password = '';
}

my $ulen = $conf->config('usernamemax')
           || $svc_acct->dbdef_table->column('username')->length;
my $ulen2 = $ulen+2;

my $pmax = $conf->config('passwordmax') || 8;
my $pmax2 = $pmax+2;

my $p1 = popurl(1);
print header("$action $svc account");

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT><BR><BR>"
  if $cgi->param('error');

print 'Service # '. ( $svcnum ? "<B>$svcnum</B>" : " (NEW)" ). '<BR>'.
      'Service: <B>'. $part_svc->svc. '</B><BR><BR>'.
      <<END;
    <FORM NAME="OneTrueForm" ACTION="${p1}process/svc_acct.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
END

print &ntable("#cccccc",2), <<END;
<TR><TD ALIGN="right">Username</TD>
<TD><INPUT TYPE="text" NAME="username" VALUE="$username" SIZE=$ulen2 MAXLENGTH=$ulen></TD></TR>
<TR><TD ALIGN="right">Password</TD>
<TD><INPUT TYPE="text" NAME="_password" VALUE="$password" SIZE=$pmax2 MAXLENGTH=$pmax>
(blank to generate)</TD>
</TR>
END

my $sec_phrase = $svc_acct->sec_phrase;
if ( $conf->exists('security_phrase') ) {
  print <<END;
  <TR><TD ALIGN="right">Security phrase</TD>
  <TD><INPUT TYPE="text" NAME="sec_phrase" VALUE="$sec_phrase" SIZE=32>
    (for forgotten passwords)</TD>
  </TD>
END
} else {
  print qq!<INPUT TYPE="hidden" NAME="sec_phrase" VALUE="$sec_phrase">!;
}

#domain
my $domsvc = $svc_acct->domsvc || 0;
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
  if ($cust_pkg && !$conf->exists('svc_acct-alldomains') ) {
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
my $popnum = $svc_acct->popnum || 0;
if ( $part_svc->part_svc_column('popnum')->columnflag eq "F" ) {
  print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$popnum">!;
} else { 
  print qq!<TR><TD ALIGN="right">Access number</TD>!.
        qq!<TD>!. FS::svc_acct_pop::popselector($popnum). '</TD></TR>';
}

my($uid,$gid,$finger,$dir)=(
  $svc_acct->uid,
  $svc_acct->gid,
  $svc_acct->finger,
  $svc_acct->dir,
);

print <<END;
<INPUT TYPE="hidden" NAME="uid" VALUE="$uid">
<INPUT TYPE="hidden" NAME="gid" VALUE="$gid">
END

if ( !$finger && $part_svc->part_svc_column('uid')->columnflag eq 'F' ) {
  print '<INPUT TYPE="hidden" NAME="finger" VALUE="">';
} else {
  print '<TR><TD ALIGN="right">GECOS</TD>'.
        qq!<TD><INPUT TYPE="text" NAME="finger" VALUE="$finger"></TD></TR>!;
}
print qq!<INPUT TYPE="hidden" NAME="dir" VALUE="$dir">!;

my $shell = $svc_acct->shell;
if ( $part_svc->part_svc_column('shell')->columnflag eq "F"
     || ( !$shell && $part_svc->part_svc_column('uid')->columnflag eq 'F' )
   ) {
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

my($quota,$slipip)=(
  $svc_acct->quota,
  $svc_acct->slipip,
);

if ( $part_svc->part_svc_column('quota')->columnflag eq "F" )
{
  print qq!<INPUT TYPE="hidden" NAME="quota" VALUE="$quota">!;
} else {
  print <<END;
    <TR><TD ALIGN="right">Quota:</TD>
        <TD> <INPUT TYPE="text" NAME="quota" VALUE="$quota" ></TD>
    </TR>
END
}

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

print '<TR><TD ALIGN="right">RADIUS groups</TD>';
if ( $part_svc->part_svc_column('usergroup')->columnflag eq "F" ) {
  print '<TD BGCOLOR="#ffffff">'. join('<BR>', @groups);
} else {
  print '<TD>'. &FS::svc_acct::radius_usergroup_selector( \@groups );
}
print '</TD></TR>';

#submit
print qq!</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">!; 

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
