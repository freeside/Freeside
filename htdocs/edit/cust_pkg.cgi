#!/usr/bin/perl -Tw
#
# $Id: cust_pkg.cgi,v 1.8 1999-07-21 07:34:13 ivan Exp $
#
# this is for changing packages around, not editing things within the package
#
# Usage: cust_pkg.cgi custnum
#        http://server.name/path/cust_pkg.cgi?custnum
#
# started with /sales/add/cust_pkg.cgi, which added packages
# ivan@voicenet.com 97-jan-5, 97-mar-21
#
# Rewrote for new API
# ivan@voicenet.com 97-jul-7
#
# FS::Search is no more, &cgisuidsetup needs $cgi, ivan@sisd.com 98-mar-7 
#
# Changes to allow page to work at a relative position in server
# Changed to display packages 2-wide in a table
#       bmccane@maxbaud.net     98-apr-3
#
# fixed a pretty cool bug from above which caused a visual glitch ivan@sisd.com
# 98-jun-1
#
# $Log: cust_pkg.cgi,v $
# Revision 1.8  1999-07-21 07:34:13  ivan
# links to package browse and agent type edit if there aren't any packages to
# order.  thanks to "Tech Account" <techy@orac.hq.org>
#
# Revision 1.7  1999/04/14 01:03:01  ivan
# oops, in 1.2 tree, can't do searches until [cgi|admin]suidsetup,
# bug is hidden by mod_perl persistance
#
# Revision 1.6  1999/02/28 00:03:36  ivan
# removed misleading comments
#
# Revision 1.5  1999/02/07 09:59:18  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:13:38  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1999/01/18 09:41:28  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.2  1998/12/17 06:17:04  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#

use strict;
use vars qw( $cgi %pkg %comment $custnum $p1 @cust_pkg 
             $cust_main $agent $type_pkgs $count %remove_pkg $pkgparts );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header popurl);
use FS::part_pkg;
use FS::type_pkgs;

$cgi = new CGI;
&cgisuidsetup($cgi);

%pkg = ();
%comment = ();
foreach (qsearch('part_pkg', {})) {
  $pkg{ $_ -> getfield('pkgpart') } = $_->getfield('pkg');
  $comment{ $_ -> getfield('pkgpart') } = $_->getfield('comment');
}

if ( $cgi->param('error') ) {
  $custnum = $cgi->param('custnum');
  %remove_pkg = map { $_ => 1 } $cgi->param('remove_pkg');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum = $1;
  undef %remove_pkg;
}

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Add/Edit Packages", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/cust_pkg.cgi" METHOD=POST>!;

print qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!;

#current packages
@cust_pkg = qsearch('cust_pkg',{ 'custnum' => $custnum, 'cancel' => '' } );

if (@cust_pkg) {
  print <<END;
Current packages - select to remove (services are moved to a new package below)
<BR><BR>
END

  my ($count) = 0 ;
  print qq!<TABLE>! ;
  foreach (@cust_pkg) {
    print '<TR>' if $count == 0;
    my($pkgnum,$pkgpart)=( $_->getfield('pkgnum'), $_->getfield('pkgpart') );
    print qq!<TD><INPUT TYPE="checkbox" NAME="remove_pkg" VALUE="$pkgnum"!;
    print " CHECKED" if $remove_pkg{$pkgnum};
    print qq!>$pkgnum: $pkg{$pkgpart} - $comment{$pkgpart}</TD>\n!;
    $count ++ ;
    if ($count == 2)
    {
      $count = 0 ;
      print qq!</TR>\n! ;
    }
  }
  print qq!</TABLE><BR><BR>!;
}

print <<END;
Order new packages<BR><BR>
END

$cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
$agent = qsearchs('agent',{'agentnum'=> $cust_main->agentnum });

$count = 0;
$pkgparts = 0;
print qq!<TABLE>!;
foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
  $pkgparts++;
  my($pkgpart)=$type_pkgs->pkgpart;
  print qq!<TR>! if ( $count == 0 );
  my $value = $cgi->param("pkg$pkgpart") || 0;
  print <<END;
  <TD>
  <INPUT TYPE="text" NAME="pkg$pkgpart" VALUE="$value" SIZE="2" MAXLENGTH="2">
  $pkgpart: $pkg{$pkgpart} - $comment{$pkgpart}</TD>\n
END
  $count ++ ;
  if ( $count == 2 ) {
    print qq!</TR>\n! ;
    $count = 0;
  }
}
print qq!</TABLE>!;

unless ( $pkgparts ) {
  my $p2 = popurl(2);
  my $typenum = $agent->typenum;
  my $agent_type = qsearchs( 'agent_type', { 'typenum' => $typenum } );
  my $atype = $agent_type->atype;
  print <<END;
(No <a href="${p2}browse/part_pkg.cgi">package definitions</a>, or agent type
<a href="${p2}edit/agent_type.cgi?$typenum">$atype</a> not allowed to purchase
any packages.)
END
}

#submit
print <<END;
<P><INPUT TYPE="submit" VALUE="Order">
    </FORM>
  </BODY>
</HTML>
END
