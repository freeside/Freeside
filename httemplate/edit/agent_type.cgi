<!-- mason kludge -->
<%

my($agent_type);
if ( $cgi->param('error') ) {
  $agent_type = new FS::agent_type ( {
    map { $_, scalar($cgi->param($_)) } fields('agent')
  } );
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $agent_type=qsearchs('agent_type',{'typenum'=>$1});
} else { #adding
  $agent_type = new FS::agent_type {};
}
my $action = $agent_type->typenum ? 'Edit' : 'Add';
my $hashref = $agent_type->hashref;

print header("$action Agent Type", menubar(
  'Main Menu' => "$p",
  'View all agent types' => "${p}browse/agent_type.cgi",
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print '<FORM ACTION="', popurl(1), 'process/agent_type.cgi" METHOD=POST>',
      qq!<INPUT TYPE="hidden" NAME="typenum" VALUE="$hashref->{typenum}">!,
      "Agent Type #", $hashref->{typenum} ? $hashref->{typenum} : "(NEW)";

print <<END;
<BR><BR>Agent Type <INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="$hashref->{atype}">
<BR><BR>Select which packages agents of this type may sell to customers<BR>
END

foreach my $part_pkg ( qsearch('part_pkg',{ 'disabled' => '' }) ) {
  print qq!<BR><INPUT TYPE="checkbox" NAME="pkgpart!,
        $part_pkg->getfield('pkgpart'), qq!" !,
       # ( 'CHECKED 'x scalar(
        qsearchs('type_pkgs',{
          'typenum' => $agent_type->getfield('typenum'),
          'pkgpart'  => $part_pkg->getfield('pkgpart'),
        })
          ? 'CHECKED '
          : '',
        qq!VALUE="ON"> !,
    qq!<A HREF="${p}edit/part_pkg.cgi?!, $part_pkg->pkgpart, 
    '">', $part_pkg->pkgpart. ": ". $part_pkg->getfield('pkg'), '</A>',
  ;
}

print qq!<BR><BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{typenum} ? "Apply changes" : "Add agent type",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
