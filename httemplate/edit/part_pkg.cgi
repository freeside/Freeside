<%
#<!-- $Id: part_pkg.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $part_pkg $action $query $hashref $part_svc $count );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::part_pkg;
use FS::part_svc;
use FS::pkg_svc;
use FS::CGI qw(header menubar popurl);

$cgi = new CGI;

&cgisuidsetup($cgi);

if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
  $cgi->param('clone', $1);
} else {
  $cgi->param('clone', '');
}
if ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
  $cgi->param('pkgnum', $1);
} else {
  $cgi->param('pkgnum', '');
}

($query) = $cgi->keywords;
$action = '';
$part_pkg = '';
if ( $cgi->param('error') ) {
  $part_pkg = new FS::part_pkg ( {
    map { $_, scalar($cgi->param($_)) } fields('part_pkg')
  } );
}
if ( $cgi->param('clone') ) {
  $action='Custom Pricing';
  my $old_part_pkg =
    qsearchs('part_pkg', { 'pkgpart' => $cgi->param('clone') } );
  $part_pkg ||= $old_part_pkg->clone;
} elsif ( $query && $query =~ /^(\d+)$/ ) {
  $part_pkg ||= qsearchs('part_pkg',{'pkgpart'=>$1});
} else {
  $part_pkg ||= new FS::part_pkg {};
}
$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
$hashref = $part_pkg->hashref;

print $cgi->header( '-expires' => 'now' ), header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print '<FORM ACTION="', popurl(1), 'process/part_pkg.cgi" METHOD=POST>';

if ( $cgi->param('clone') ) {
  print qq!<INPUT TYPE="hidden" NAME="clone" VALUE="!, $cgi->param('clone'), qq!">!;
}
if ( $cgi->param('pkgnum') ) {
  print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="!, $cgi->param('pkgnum'), qq!">!;
}

print qq!<INPUT TYPE="hidden" NAME="pkgpart" VALUE="$hashref->{pkgpart}">!,
      "Package Part #", $hashref->{pkgpart} ? $hashref->{pkgpart} : "(NEW)";

print <<END;
<PRE>
Package (customer-visable)          <INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="$hashref->{pkg}">
Comment (customer-hidden)           <INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="$hashref->{comment}">
Setup fee for this package          <INPUT TYPE="text" NAME="setup" VALUE="$hashref->{setup}">
Recurring fee for this package      <INPUT TYPE="text" NAME="recur" VALUE="$hashref->{recur}">
Frequency (months) of recurring fee <INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}">

</PRE>

END

unless ( $cgi->param('clone') ) {
  print <<END;
Enter the quantity of each service this package includes.<BR><BR>
<TABLE BORDER><TR><TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH>
		  <TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH></TR>
END
}

$count = 0;
foreach $part_svc ( ( qsearch( 'part_svc', {} ) ) ) {
  my $svcpart = $part_svc->svcpart;
  my $pkg_svc = qsearchs( 'pkg_svc', {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
  } ) || new FS::pkg_svc ( {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
    'quantity' => 0,
  });
  #? #next unless $pkg_svc;

  unless ( defined ($cgi->param('clone')) && $cgi->param('clone') ) {
    print '<TR>' if $count == 0 ;
    print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=3 VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0,
          qq!"></TD><TD><A HREF="part_svc.cgi?!,$part_svc->svcpart,
          qq!">!, $part_svc->getfield('svc'), "</A></TD>";
    $count++;
    if ($count == 2)
    {
      print '</TR>';
      $count = 0;
    }
  } else {
    print qq!<INPUT TYPE="hidden" NAME="pkg_svc$svcpart" VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0, qq!">\n!;
  }
}

unless ( $cgi->param('clone') ) {
  print qq!</TR>! if ($count != 0) ;
  print "</TABLE>";
}

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{pkgpart} ? "Apply changes" : "Add package",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

%>
