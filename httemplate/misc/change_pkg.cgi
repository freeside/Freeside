<!-- mason kludge -->
<%

my $pkgnum;
if ( $cgi->param('error') ) {
  #$custnum = $cgi->param('custnum');
  #%remove_pkg = map { $_ => 1 } $cgi->param('remove_pkg');
  $pkgnum = ($cgi->param('remove_pkg'))[0];
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  #$custnum = $1;
  $pkgnum = $1;
  #%remove_pkg = ();
}

my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } )
  or die "unknown pkgnum $pkgnum";
my $custnum = $cust_pkg->custnum;

my $conf = new FS::Conf;

my $p1 = popurl(1);

my $cust_main = $cust_pkg->cust_main
  or die "can't get cust_main record for custnum ". $cust_pkg->custnum.
         " ( pkgnum ". cust_pkg->pkgnum. ")";
my $agent = $cust_main->agent;

print header("Change Package",  menubar(
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
  'Main Menu' => $p,
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT><BR><BR>"
  if $cgi->param('error');

my $part_pkg = $cust_pkg->part_pkg;

print small_custview( $cust_main, $conf->config('countrydefault') ).
      qq!<FORM ACTION="${p}edit/process/cust_pkg.cgi" METHOD=POST>!.
      qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!.
      qq!<INPUT TYPE="hidden" NAME="remove_pkg" VALUE="$pkgnum">!.
      '<BR>Current package: '. $part_pkg->pkg. ' - '. $part_pkg->comment.
      qq!<BR>New package: <SELECT NAME="new_pkgpart"><OPTION VALUE=0></OPTION>!;

foreach my $part_pkg (
  grep { ! $_->disabled && $_->pkgpart != $cust_pkg->pkgpart }
    map { $_->part_pkg } $agent->agent_type->type_pkgs
) {
  my $pkgpart = $part_pkg->pkgpart;
  print qq!<OPTION VALUE="$pkgpart"!;
  print ' SELECTED' if $cgi->param('error')
                       && $cgi->param('new_pkgpart') == $pkgpart;
  print qq!>$pkgpart: !. $part_pkg->pkg. ' - '. $part_pkg->comment. '</OPTION>';
}

print <<END;
</SELECT>
<BR><BR><INPUT TYPE="submit" VALUE="Change package">
    </FORM>
  </BODY>
</HTML>
END
%>
