#!/usr/bin/perl -Tw
#
# part_pkg.cgi: Add/Edit package (output form)
#
# ivan@sisd.com 97-dec-10
#
# Changes to allow page to work at a relative position in server
# Changed to display services 2-wide in table
#       bmccane@maxbaud.net     98-apr-3
#
# use FS::CGI, added inline documentation ivan@sisd.com 98-jul-12

use strict;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;
use FS::pkg_svc;
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

my($part_pkg,$action);
if ( $cgi->var('QUERY_STRING') =~ /^(\d+)$/ ) { #editing
  $part_pkg=qsearchs('part_pkg',{'pkgpart'=>$1});
  $action='Edit';
} else { #adding
  $part_pkg=create FS::part_pkg {};
  $action='Add';
}
my($hashref)=$part_pkg->hashref;

print header("$action Package Definition", menubar(
  'Main Menu' => '../',
  'View all packages' => '../browse/part_pkg.cgi',
)), '<FORM ACTION="process/part_pkg.cgi" METHOD=POST>';

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

Enter the quantity of each service this package includes.<BR><BR>
<TABLE BORDER><TR><TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH>
		  <TH><FONT SIZE=-1>Quan.</FONT></TH><TH>Service</TH></TR>
END

my($part_svc);
my($count) = 0 ;
foreach $part_svc ( qsearch('part_svc',{}) ) {

  my($svcpart)=$part_svc->getfield('svcpart');
  my($pkg_svc)=qsearchs('pkg_svc',{
    'pkgpart'  => $part_pkg->getfield('pkgpart'),
    'svcpart'  => $svcpart,
  })  || create FS::pkg_svc({
    'pkgpart'  => $part_pkg->getfield('pkgpart'),
    'svcpart'  => $svcpart,
    'quantity' => 0,
  });
  next unless $pkg_svc;

  print qq!<TR>! if $count == 0 ;
  print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=3 VALUE="!,
        $pkg_svc->getfield('quantity') || 0,qq!"></TD>!,
        qq!<TD><A HREF="part_svc.cgi?!,$part_svc->getfield('svcpart'),
        qq!">!, $part_svc->getfield('svc'), "</A></TD>";
  $count ++ ;
  if ($count == 2)
  {
    print qq!</TR>! ;
    $count = 0 ;
  }
}
print qq!</TR>! if ($count != 0) ;

print "</TABLE>";

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{pkgpart} ? "Apply changes" : "Add package",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

