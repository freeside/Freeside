#!/usr/bin/perl -Tw
#
# $Id: part_pkg.cgi,v 1.7 1999-01-18 09:41:29 ivan Exp $
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
#
# $Log: part_pkg.cgi,v $
# Revision 1.7  1999-01-18 09:41:29  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.6  1998/12/17 06:17:05  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.5  1998/11/21 07:12:26  ivan
# *** empty log message ***
#
# Revision 1.4  1998/11/21 07:11:08  ivan
# *** empty log message ***
#
# Revision 1.3  1998/11/21 07:07:40  ivan
# popurl, bugfix
#
# Revision 1.2  1998/11/15 13:14:55  ivan
# first pass as per-user custom pricing
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;
use FS::part_svc;
use FS::pkg_svc;
use FS::CGI qw(header menubar popurl);

my($cgi) = new CGI;

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

my($part_pkg,$action);
my($query) = $cgi->keywords;
if ( $cgi->param('clone') ) {
  $action='Custom Pricing';
  my $old_part_pkg =
    qsearchs('part_pkg', { 'pkgpart' => $cgi->param('clone') } );
  $part_pkg = $old_part_pkg->clone;
} elsif ( $query =~ /^(\d+)$/ ) {
  $action='Edit';
  $part_pkg=qsearchs('part_pkg',{'pkgpart'=>$1});
} else {
  $action='Add';
  $part_pkg=create FS::part_pkg {};
}
my($hashref)=$part_pkg->hashref;

print $cgi->header( '-expires' => 'now' ), header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
)), '<FORM ACTION="', popurl(1), 'process/part_pkg.cgi" METHOD=POST>';

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

my($part_svc);
my($count) = 0 ;
foreach $part_svc ( qsearch('part_svc',{}) ) {

  my($svcpart)=$part_svc->getfield('svcpart');
  my($pkg_svc)=qsearchs('pkg_svc',{
    'pkgpart'  => $cgi->param('clone') || $part_pkg->getfield('pkgpart'),
    'svcpart'  => $svcpart,
  })  || create FS::pkg_svc({
    'pkgpart'  => $part_pkg->getfield('pkgpart'),
    'svcpart'  => $svcpart,
    'quantity' => 0,
  });
  next unless $pkg_svc;

  unless ( $cgi->param('clone') ) {
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
  } else {
    print qq!<INPUT TYPE="hidden" NAME="pkg_svc$svcpart" VALUE="!,
          $pkg_svc->getfield('quantity') || 0, qq!">\n!;
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

