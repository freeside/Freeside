<%
#<!-- $Id: agent_type.cgi,v 1.5 2001-10-30 14:54:07 ivan Exp $ -->

use strict;
use vars qw( $cgi $agent_type $action $hashref $p $part_pkg );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::agent_type;
use FS::CGI qw(header menubar popurl);
use FS::agent_type;
use FS::part_pkg;
use FS::type_pkgs;

$cgi = new CGI;

&cgisuidsetup($cgi);

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
$action = $agent_type->typenum ? 'Edit' : 'Add';
$hashref = $agent_type->hashref;

$p = popurl(2);
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

foreach $part_pkg ( qsearch('part_pkg',{}) ) {
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
    '">', $part_pkg->getfield('pkg'), '</A>',
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
