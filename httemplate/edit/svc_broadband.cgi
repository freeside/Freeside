<!-- mason kludge -->
<%

my( $svcnum,  $pkgnum, $svcpart, $part_svc, $svc_broadband );
if ( $cgi->param('error') ) {
  $svc_broadband = new FS::svc_broadband ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_broadband')
  } );
  $svcnum = $svc_broadband->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_broadband=qsearchs('svc_broadband',{'svcnum'=>$svcnum})
      or die "Unknown (svc_broadband) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_broadband = new FS::svc_broadband({});

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svcnum='';

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_broadband->setfield( $part_svc_column->columnname,
                                $part_svc_column->columnvalue,
                              );
    }

  }
}
my $action = $svc_broadband->svcnum ? 'Edit' : 'Add';

my @ac_list;

if ($pkgnum) {

  unless ($svc_broadband->actypenum) {die "actypenum must be set fixed";};
  @ac_list = qsearch('ac', { actypenum => $svc_broadband->getfield('actypenum') });

} elsif ( $action eq 'Edit' ) {

  #Nothing?

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}


my $p1 = popurl(1);
print header("Broadband Service $action", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/svc_broadband.cgi" METHOD=POST>!;

#display

 

#svcnum
print qq!<INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">!;
print qq!Service #<B>!, $svcnum ? $svcnum : "(NEW)", "</B><BR><BR>";

#pkgnum
print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!;
 
#svcpart
print qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">!;

#actypenum
print '<INPUT TYPE="hidden" NAME="actypenum" VALUE="' .
      $svc_broadband->actypenum . '">';


print &ntable("#cccccc",2) . qq!<TR><TD ALIGN="right">AC</TD><TD>!;

#acnum
if (( $part_svc->part_svc_column('acnum')->columnflag eq 'F' ) or
    ( !$pkgnum )) {

  my $ac = qsearchs('ac', { acnum => $svc_broadband->acnum });
  my ($acnum, $acname) = ($ac->acnum, $ac->acname);

  print qq!<INPUT TYPE="hidden" NAME="acnum" VALUE="${acnum}">! .
        qq!${acnum}: ${acname}</TD></TR>!;

} else {

  my @ac_list = qsearch('ac', { actypenum => $svc_broadband->actypenum });
  print qq!<SELECT NAME="acnum" SIZE="1"><OPTION VALUE=""></OPTION>!;

  foreach ( @ac_list ) {
    my ($acnum, $acname) = ($_->acnum, $_->acname);
    print qq!<OPTION VALUE="${acnum}"! .
          ($acnum == $svc_broadband->acnum ? ' SELECTED>' : '>') .
          qq!${acname}</OPTION>!;
  }
  print '</TD></TR>';

}

#speed_up & speed_down
my ($speed_up, $speed_down) = ($svc_broadband->speed_up,
                               $svc_broadband->speed_down);

print '<TR><TD ALIGN="right">Download speed</TD><TD>';
if ( $part_svc->part_svc_column('speed_down')->columnflag eq 'F' ) {
  print qq!<INPUT TYPE="hidden" NAME="speed_down" VALUE="${speed_down}">! .
        qq!${speed_down}Kbps</TD></TR>!;
} else {
  print qq!<INPUT TYPE="text" NAME="speed_down" SIZE=5 VALUE="${speed_down}">! .
        qq!Kbps</TD></TR>!;
}

print '<TR><TD ALIGN="right">Upload speed</TD><TD>';
if ( $part_svc->part_svc_column('speed_up')->columnflag eq 'F' ) {
  print qq!<INPUT TYPE="hidden" NAME="speed_up" VALUE="${speed_up}">! .
        qq!${speed_up}Kbps</TD></TR>!;
} else {
  print qq!<INPUT TYPE="text" NAME="speed_up" SIZE=5 VALUE="${speed_up}">! .
        qq!Kbps</TD></TR>!;
}

#ip_addr & ip_netmask
#We're assuming that ip_netmask is fixed if ip_addr is fixed.
#If it isn't, well, <shudder> what the heck are you doing!?!?

my ($ip_addr, $ip_netmask) = ($svc_broadband->ip_addr,
                              $svc_broadband->ip_netmask);

print '<TR><TD ALIGN="right">IP address/Mask</TD><TD>';
if ( $part_svc->part_svc_column('ip_addr')->columnflag eq 'F' ) {
  print qq!<INPUT TYPE="hidden" NAME="ip_addr" VALUE="${ip_addr}">! .
        qq!<INPUT TYPE="hidden" NAME="ip_netmask" VALUE="${ip_netmask}">! .
        qq!${ip_addr}/${ip_netmask}</TD></TR>!;
} else {
  $ip_addr =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
  print <<END;
  <INPUT TYPE="text" NAME="ip_addr_a" SIZE="3" MAXLENGTH="3" VALUE="${1}">.
  <INPUT TYPE="text" NAME="ip_addr_b" SIZE="3" MAXLENGTH="3" VALUE="${2}">.
  <INPUT TYPE="text" NAME="ip_addr_c" SIZE="3" MAXLENGTH="3" VALUE="${3}">.
  <INPUT TYPE="text" NAME="ip_addr_d" SIZE="3" MAXLENGTH="3" VALUE="${4}">/
  <INPUT TYPE="text" NAME="ip_netmask" SIZE="2" MAXLENGTH="2" VALUE="${ip_netmask}">
</TD></TR>
<TR><TD COLSPAN="2" WIDTH="300">
<P><SMALL>Leave the IP address and netmask blank for automatic assignment of a /32 address.  Specifing the netmask and not the address will force assignment of a larger block.</SMALL></P>
</TD></TR>
END
}

#mac_addr
my $mac_addr = $svc_broadband->mac_addr;

unless (( $part_svc->part_svc_column('mac_addr')->columnflag eq 'F' ) and
        ( $mac_addr eq '' )) {
  print '<TR><TD ALIGN="right">MAC Address</TD><TD>';
  if ( $part_svc->part_svc_column('mac_addr')->columnflag eq 'F' ) { #Why?
    print qq!<INPUT TYPE="hidden" NAME="mac_addr" VALUE="${mac_addr}">! .
          qq!${mac_addr}</TD></TR>!;
  } else {
    #Ewwww
    $mac_addr =~ /^([a-f0-9]{2}):([a-f0-9]{2}):([a-f0-9]{2}):([a-f0-9]{2}):([a-f0-9]{2}):([a-f0-9]{2})$/i;
    print <<END;
  <INPUT TYPE="text" NAME="mac_addr_a" SIZE="2" MACLENGTH="2" VALUE="${1}">:
  <INPUT TYPE="text" NAME="mac_addr_b" SIZE="2" MACLENGTH="2" VALUE="${2}">:
  <INPUT TYPE="text" NAME="mac_addr_c" SIZE="2" MACLENGTH="2" VALUE="${3}">:
  <INPUT TYPE="text" NAME="mac_addr_d" SIZE="2" MACLENGTH="2" VALUE="${4}">:
  <INPUT TYPE="text" NAME="mac_addr_e" SIZE="2" MACLENGTH="2" VALUE="${5}">:
  <INPUT TYPE="text" NAME="mac_addr_f" SIZE="2" MACLENGTH="2" VALUE="${6}">
</TD></TR>
END

  }
}

#location
my $location = $svc_broadband->location;

print '<TR><TD VALIGN="top" ALIGN="right">Location</TD><TD BGCOLOR="#e8e8e8">';
if ( $part_svc->part_svc_column('location')->columnflag eq 'F' ) {
  print qq!<PRE>${location}</PRE></TD></TR>!;
} else {
  print qq!<TEXTAREA ROWS="4" COLS="30" NAME="location">${location}</TEXTAREA>!;
}

print '</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">';

print <<END;

    </FORM>
  </BODY>
</HTML>
END
%>
