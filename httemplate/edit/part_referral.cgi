<!-- mason kludge -->
<%

my $part_referral;
if ( $cgi->param('error') ) {
  $part_referral = new FS::part_referral ( {
    map { $_, scalar($cgi->param($_)) } fields('part_referral')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $part_referral = qsearchs( 'part_referral', { 'refnum' => $1 } );
} else { #adding
  $part_referral = new FS::part_referral {};
}
my $action = $part_referral->refnum ? 'Edit' : 'Add';
my $hashref = $part_referral->hashref;

my $p1 = popurl(1);
print header("$action Advertising source", menubar(
  'Main Menu' => popurl(2),
  'View all advertising sources' => popurl(2). "browse/part_referral.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/part_referral.cgi" METHOD=POST>!;

print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$hashref->{refnum}">!;
#print "Referral #", $hashref->{refnum} ? $hashref->{refnum} : "(NEW)";

print <<END;
Advertising source <INPUT TYPE="text" NAME="referral" SIZE=32 VALUE="$hashref->{referral}">
END

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{refnum} ? "Apply changes" : "Add advertising source",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
