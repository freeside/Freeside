<!-- mason kludge -->
<%

my $ac_type;
if ( $cgi->param('error') ) {
  $ac_type = new FS::ac_type ( {
    map { $_, scalar($cgi->param($_)) } fields('ac_type')
  } );
} elsif ( $cgi->keywords ) { #editing
  my($query)=$cgi->keywords;
  $query =~ /^(\d+)$/;
  $ac_type=qsearchs('ac_type',{'actypenum'=>$1});
} else { #adding
  $ac_type = new FS::ac_type {};
}
my $action = $ac_type->actypenum ? 'Edit' : 'Add';
my $hashref = $ac_type->hashref;

my @ut_types = qw( float number text alpha anything ip domain );

my $p1 = popurl(1);
print header("$action Access Concentrator Type", menubar(
  'Main Menu' => popurl(2),
  'View all Access Concentrator types' => popurl(2). "browse/ac_type.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/ac_type.cgi" METHOD=POST>!;

#display

print qq!<INPUT TYPE="hidden" NAME="actypenum" VALUE="$hashref->{actypenum}">!,
      "AC Type #", $hashref->{actypenum} ? $hashref->{actypenum} : "(NEW)";

print <<TROZ;
<PRE>
AC Type Name <INPUT TYPE="text" NAME="actypename" SIZE=15 VALUE="$hashref->{actypename}">
</PRE>

TROZ

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{actypenum} ? "Apply changes" : "Add AC Type",
      qq!"></FORM>!;


if ($hashref->{actypenum}) {
  print qq!   <BR>Available fields:<BR>! .  table();

  print qq!    <TH><TD>Field name</TD><TD>Field type</TD><TD></TD></TH>!;

  my @part_ac_field = qsearch ( 'part_ac_field',
                                { actypenum => $hashref->{actypenum} } );
  foreach ( @part_ac_field ) {
    my $pf_hashref = $_->hashref;
    print <<END;
      <TR>
        <TD>$pf_hashref->{acfieldpart}</TD>
        <TD>$pf_hashref->{name}</TD>
        <TD>$pf_hashref->{ut_type}</TD>
      </TR>
END
  }

  my $name, $ut_type = '';
  if ($cgi->param('error')) {
    $name = $cgi->param('name');
    $ut_type = $cgi->param('ut_type');
  }

  print <<END;
      <FORM ACTION="${p1}process/part_ac_field.cgi" METHOD=GET>
      <TR>
       <TD><SMALL>(NEW)</SMALL>
         <INPUT TYPE="hidden" NAME="actypenum" VALUE="$hashref->{actypenum}">
       </TD>
       <TD>
         <INPUT TYPE="text" NAME="name" VALUE="${name}">
       </TD>
       <TD>
         <SELECT NAME="ut_type" SIZE=1><OPTION>
END

  foreach ( @ut_types ) {
    print qq!<OPTION! . ($ut_type ? " SELECTED>$_" : ">$_");
  }

  print <<END;
        </SELECT>
      </TD>
      <TD><INPUT TYPE="submit" VALUE="Add"></TD>
    </TR>
    </FORM>
  </TABLE>
END

}

%>

 </BODY>
</HTML>

