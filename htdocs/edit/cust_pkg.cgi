#!/usr/bin/perl -Tw
#
# $Id: cust_pkg.cgi,v 1.4 1999-01-19 05:13:38 ivan Exp $
#
# this is for changing packages around, not editing things within the package
#
# Usage: cust_pkg.cgi custnum
#        http://server.name/path/cust_pkg.cgi?custnum
#
# Note: Should be run setuid freeside as user nobody
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
# Revision 1.4  1999-01-19 05:13:38  ivan
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
use vars qw( $cgi %pkg %comment $query $custnum $otaker $p1 @cust_pkg 
             $cust_main $agent $type_pkgs $count );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header popurl);
use FS::part_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);

foreach (qsearch('part_pkg', {})) {
  $pkg{ $_ -> getfield('pkgpart') } = $_->getfield('pkg');
  $comment{ $_ -> getfield('pkgpart') } = $_->getfield('comment');
}

#untaint custnum

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$custnum = $1;

$otaker = &getotaker;

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Add/Edit Packages", ''), <<END;
    <FORM ACTION="${p1}process/cust_pkg.cgi" METHOD=POST>
    <HR>
END

#custnum
print qq!<INPUT TYPE="hidden" NAME="new_custnum" VALUE="$custnum">!;

#current packages (except cancelled packages)
@cust_pkg = grep ! $_->getfield('cancel'),
  qsearch('cust_pkg',{'custnum'=>$custnum});

if (@cust_pkg) {
  print <<END;
<CENTER><FONT SIZE="+2">Current packages</FONT></CENTER>
These are packages the customer currently has.  Select those packages you
wish to remove (if any).<BR><BR>
END

  my ($count) = 0 ;
  print qq!<CENTER><TABLE>! ;
  foreach (@cust_pkg) {
    print qq!<TR>! if ($count ==0) ;
    my($pkgnum,$pkgpart)=( $_->getfield('pkgnum'), $_->getfield('pkgpart') );
    print qq!<TD><INPUT TYPE="checkbox" NAME="remove_pkg" VALUE="$pkgnum">!,
          #qq!$pkgnum: $pkg{$pkgpart} - $comment{$pkgpart}</TD>\n!,
          #now you've got to admit this bug was pretty cool
          qq!$pkgnum: $pkg{$pkgpart} - $comment{$pkgpart}</TD>\n!;
    $count ++ ;
    if ($count == 2)
    {
      $count = 0 ;
      print qq!</TR>\n! ;
    }
  }
  print qq!</TABLE></CENTER>! ;

  print "<HR>";
}

print <<END;
<CENTER><FONT SIZE="+2">New packages</FONT></CENTER>
These are packages the customer can purchase.  Specify the quantity to add
of each package.<BR><BR>
END

$cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
$agent = qsearchs('agent',{'agentnum'=> $cust_main->agentnum });

$count = 0 ;
print qq!<CENTER><TABLE>! ;
foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
  my($pkgpart)=$type_pkgs->pkgpart;
  print qq!<TR>! if ($count == 0) ;
  print <<END;
  <TD>
  <INPUT TYPE="text" NAME="pkg$pkgpart" VALUE="0" SIZE="2" MAXLENGTH="2">
  $pkgpart: $pkg{$pkgpart} - $comment{$pkgpart}</TD>\n
END
  $count ++ ;
  if ($count == 2)
  {
    print qq!</TR>\n! ;
    $count = 0 ;
  }
}
print qq!</TABLE></CENTER>! ;

#otaker
print qq!<INPUT TYPE="hidden" NAME="new_otaker" VALUE="$otaker">\n!;

#submit
print qq!<P><CENTER><INPUT TYPE="submit" VALUE="Order"></CENTER>\n!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END
