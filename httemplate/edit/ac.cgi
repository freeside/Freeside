<!-- mason kludge -->
<%

my($ac);
if ( $cgi->param('error') ) {
  $ac = new FS::ac ( {
    map { $_, scalar($cgi->param($_)) } fields('ac')
  } );
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $ac=qsearchs('ac',{'acnum'=>$1});
} else { #adding
  $ac = new FS::ac {};
}
my $action = $ac->acnum ? 'Edit' : 'Add';
my $hashref = $ac->hashref;

print header("$action Access Concentrator", menubar(
  'Main Menu' => "$p",
  'View all access concentrators' => "${p}browse/ac.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print '<FORM ACTION="', popurl(1), 'process/ac.cgi" METHOD=POST>',
      qq!<INPUT TYPE="hidden" NAME="acnum" VALUE="$hashref->{acnum}">!,
      "Access Concentrator #", $hashref->{acnum} ? $hashref->{acnum} : "(NEW)";

print <<END;

<TABLE COLOR="#cccccc">
  <TR>
    <TH ALIGN="RIGHT">Access Concentrator</TH>
    <TD>
      <INPUT TYPE="text" NAME="acname" SIZE=15 VALUE="$hashref->{acname}">
    </TD>
  </TD>
END


if (! $ac->acnum) {
  print <<END;
  <TR>
    <TH ALIGN="RIGHT">Access Concentrator Type</TH>
    <TD><SELECT NAME="actypenum" SIZE="1"><OPTION VALUE=""></OPTION>
END

  foreach (qsearch('ac_type', {})) {
    my $narf = $_->hashref;
    print qq!<OPTION! .
          ($narf->{actypenum} eq $hashref->{actypenum} ? ' SELECTED' : '') .
          qq! VALUE="$narf->{actypenum}">$narf->{actypenum}: $narf->{actypename}! .
          qq!</OPTION>!;
  }

  print '</TD></TR></TABLE>';
} else {
  print '</TABLE>';
  print qq!<INPUT TYPE="hidden" NAME="actypenum" VALUE="$hashref->{actypenum}">!;
}

print qq!</TABLE><BR><BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{acnum} ? "Apply changes" : "Add access concentrator",
      qq!"></FORM>!;

if ($hashref->{acnum}) {
  print table();
  print <<END;
    Additional Fields:<BR>
    <TH>
      <TD>Field Name</TD>
      <TD COLSPAN=2>Field Value</TD>
    </TH>
END

  #my @ac_fields = qsearch('ac_field', { acnum => $hashref->{acnum} });
  my @ac_fields = $ac->ac_field;
  foreach (@ac_fields) {
    print qq!\n<TR><TD></TD>!;
    my $part_ac_field = qsearchs('part_ac_field',
                          { acfieldpart => $_->getfield('acfieldpart') });
    print '<TD>' . $part_ac_field->getfield('name') .
          '</TD><TD>' . $_->getfield('value') . '</TD></TR>';
    print "\n";
  }

  print '<FORM ACTION="', popurl(1), 'process/ac_field.cgi" METHOD=POST>';
  print <<END;
    <TR>
      <TD><INPUT TYPE="hidden" NAME="acnum" VALUE="$hashref->{acnum}">
          <INPUT TYPE="hidden" NAME="acname" VALUE="$hashref->{acname}">
          <INPuT TYPE="hidden" NAME="actypenum" VALUE="$hashref->{actypenum}">
          <SMALL>(NEW)</SMALL>
      </TD>
      <TD><SELECT NAME="acfieldpart"><OPTION></OPTION>
END

  my @part_ac_fields = qsearch('part_ac_field',
                         { actypenum => $hashref->{actypenum} });
  foreach my $part_ac_field (@part_ac_fields) {
    my $acfieldpart = $part_ac_field->getfield('acfieldpart');
    if (grep {$_->getfield('acfieldpart') eq $acfieldpart} @ac_fields) {next;}
    print qq!<OPTION VALUE="${acfieldpart}">! .
          $part_ac_field->getfield('name') . '</OPTION>';
  }

  print <<END;
        </SELECT>
      </TD>
      <TD><INPUT TYPE="text" SIZE="15" NAME="value"></TD>
      <TD><INPUT TYPE="submit" VALUE="Add"></TD>
    </TR>
    </FORM>
  </TABLE>
END

}

if ($hashref->{acnum}) {

  print qq!<BR><BR>IP Address Blocks:<BR>! . table() .
        qq!<TR><TH></TH><TH>Network/Mask</TH>! .
        qq!<TH>Gateway Address</TH><TH>Mask length</TH></TR>\n!;

  foreach (qsearch('ac_block', { acnum => $hashref->{acnum} })) {
    my $ip_addr = new NetAddr::IP($_->getfield('ip_gateway'),
                                  $_->getfield('ip_netmask'));
    print qq!<TR><TD></TD><TD>! . $ip_addr->network->addr() . '/' .
          $ip_addr->network->mask() . qq!</TD>!;

    print qq!<TD>! . $_->getfield('ip_gateway') . qq!</TD>\n! .
          qq!<TD>! . $_->getfield('ip_netmask') . qq!</TD></TR>!;

  }

  print '<FORM ACTION="', popurl(1), 'process/ac_block.cgi" METHOD=POST>';
  print <<END;
  <TR>
    <TD><INPUT TYPE="hidden" NAME="acnum" VALUE="$hashref->{acnum}">
        <INPUT TYPE="hidden" NAME="acname" VALUE="$hashref->{acname}">
        <INPuT TYPE="hidden" NAME="actypenum" VALUE="$hashref->{actypenum}">
       <SMALL>(NEW)</SMALL>
    </TD>
    <TD></TD>
    <TD><INPUT TYPE="text" NAME="ip_gateway" SIZE="15"></TD>
    <TD><INPUT TYPE="text" NAME="ip_netmask" SIZE="2"></TD>
    <TD><INPUT TYPE="submit" VALUE="Add"></TD>
  </TR>
  </FORM>
</TABLE>
END

}

print <<END;
  </BODY>
</HTML>
END

%>
