#!/usr/bin/perl -Tw
#
# $Id: cust_pkg.cgi,v 1.9 1999-04-08 12:00:19 ivan Exp $
#
# Usage: cust_pkg.cgi pkgnum
#        http://server.name/path/cust_pkg.cgi?pkgnum
#
# ivan@voicenet.com 96-dec-15
#
# services section needs to be cleaned up, needs to display extraneous
# entries in cust_pkg!
# ivan@voicenet.com 96-dec-31
#
# added navigation bar
# ivan@voicenet.com 97-jan-30
#
# changed and fixed up suspension and cancel stuff, now you can't add
# services to a cancelled package
# ivan@voicenet.com 97-feb-27
#
# rewrote for new API, still needs to be cleaned up!
# ivan@voicenet.com 97-jul-29
#
# no FS::Search ivan@sisd.com 98-mar-7
# 
# $Log: cust_pkg.cgi,v $
# Revision 1.9  1999-04-08 12:00:19  ivan
# aesthetic update
#
# Revision 1.8  1999/02/28 00:04:01  ivan
# removed misleading comments
#
# Revision 1.7  1999/01/19 05:14:20  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 09:41:44  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.5  1998/12/23 03:11:40  ivan
# *** empty log message ***
#
# Revision 1.3  1998/12/17 09:57:22  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/11/13 09:56:49  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use vars qw ( $cgi %uiview %uiadd $part_svc $query $pkgnum $cust_pkg $part_pkg
              $custnum $susp $cancel $expire $pkg $comment $setup $bill
              $otaker );
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl header menubar ntable table);
use FS::Record qw(qsearch qsearchs);
use FS::part_svc;
use FS::cust_pkg;
use FS::part_pkg;
use FS::pkg_svc;
use FS::cust_svc;

$cgi = new CGI;
cgisuidsetup($cgi);

foreach $part_svc ( qsearch('part_svc',{}) ) {
  $uiview{$part_svc->svcpart} = popurl(2). "view/". $part_svc->svcdb . ".cgi";
  $uiadd{$part_svc->svcpart}= popurl(2). "edit/". $part_svc->svcdb . ".cgi";
}

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$pkgnum = $1;

#get package record
$cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
die "No package!" unless $cust_pkg;
$part_pkg = qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->getfield('pkgpart')});

$custnum = $cust_pkg->getfield('custnum');
print $cgi->header( '-expires' => 'now' ), header('Package View', menubar(
  "View this customer (#$custnum)" => popurl(2). "view/cust_main.cgi?$custnum",
  'Main Menu' => popurl(2)
));

#print info
($susp,$cancel,$expire)=(
  $cust_pkg->getfield('susp'),
  $cust_pkg->getfield('cancel'),
  $cust_pkg->getfield('expire'),
);
($pkg,$comment)=($part_pkg->getfield('pkg'),$part_pkg->getfield('comment'));
($setup,$bill)=($cust_pkg->getfield('setup'),$cust_pkg->getfield('bill'));
$otaker = $cust_pkg->getfield('otaker');

print "Package information";
print ' (<A HREF="'. popurl(2). 'misc/unsusp_pkg.cgi?'. $pkgnum.
      '">unsuspend</A>)' if ( $susp && ! $cancel );
print ' (<A HREF="'. popurl(2). 'misc/susp_pkg.cgi?'. $pkgnum.
      '">suspend</A>)' unless ( $susp || $cancel );
print ' (<A HREF="'. popurl(2). 'misc/cancel_pkg.cgi?'. $pkgnum.
      '">cancel</A>)' unless $cancel;

print ntable("#c0c0c0"), '<TR><TD>', ntable("#c0c0c0",2),
      '<TR><TD ALIGN="right">Package number</TD><TD BGCOLOR="#ffffff">',
      $pkgnum, '</TD></TR>',
      '<TR><TD ALIGN="right">Package</TD><TD BGCOLOR="#ffffff">',
      $pkg,  '</TD></TR>',
      '<TR><TD ALIGN="right">Comment</TD><TD BGCOLOR="#ffffff">',
      $comment,  '</TD></TR>',
      '<TR><TD ALIGN="right">Setup date</TD><TD BGCOLOR="#ffffff">',
      ( $setup ? time2str("%D",$setup) : "(Not setup)" ), '</TD></TR>',
      '<TR><TD ALIGN="right">Next bill date</TD><TD BGCOLOR="#ffffff">',
      ( $bill ? time2str("%D",$bill) : "&nbsp;" ), '</TD></TR>',
;
print '<TR><TD ALIGN="right">Suspension date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$susp), '</TD></TR>' if $susp;
print '<TR><TD ALIGN="right">Expiration date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$expire), '</TD></TR>' if $expire;
print '<TR><TD ALIGN="right">Cancellation date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$cancel), '</TD></TR>' if $cancel;
print  '<TR><TD ALIGN="right">Order taker</TD><TD BGCOLOR="#ffffff">',
      $otaker,  '</TD></TR>',
      '</TABLE></TD></TR></TABLE>'
;

#  print <<END;
#<FORM ACTION="../misc/expire_pkg.cgi" METHOD="post">
#<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
#Expire (date): <INPUT TYPE="text" NAME="date" VALUE="" >
#<INPUT TYPE="submit" VALUE="Cancel later">
#END

unless ($cancel) {

  #services
  print '<BR>Service Information', table,
  ;

  #list of services this pkgpart includes
  my $pkg_svc;
  my %pkg_svc = ();
  foreach $pkg_svc ( qsearch('pkg_svc',{'pkgpart'=> $cust_pkg->pkgpart }) ) {
    $pkg_svc{$pkg_svc->svcpart} = $pkg_svc->quantity if $pkg_svc->quantity;
  }

  #list of records from cust_svc
  my $svcpart;
  foreach $svcpart (sort {$a <=> $b} keys %pkg_svc) {

    my($svc)=qsearchs('part_svc',{'svcpart'=>$svcpart})->getfield('svc');

    my(@cust_svc)=qsearch('cust_svc',{'pkgnum'=>$pkgnum, 
                                      'svcpart'=>$svcpart,
                                     });

    my($enum);
    for $enum ( 1 .. $pkg_svc{$svcpart} ) {

      my($cust_svc);
      if ( $cust_svc=shift @cust_svc ) {
        my($svcnum)=$cust_svc->svcnum;
        my($label, $value, $svcdb) = $cust_svc->label;
        print <<END;
<TR><TD><A HREF="$uiview{$svcpart}?$svcnum">(View) $svc: $value<A></TD></TR>
END
      } else {
        print <<END;
<TR>
  <TD><A HREF="$uiadd{$svcpart}?pkgnum$pkgnum-svcpart$svcpart">
      (Add) $svc</A>
   or <A HREF="../misc/link.cgi?pkgnum$pkgnum-svcpart$svcpart">
      (Link to existing) $svc</A>
  </TD>
</TR>
END
      }

    }
    warn "WARNING: Leftover services pkgnum $pkgnum!" if @cust_svc;; 
  }

  print "</TABLE><FONT SIZE=-1>",
        "Choose (View) to view or edit an existing service<BR>",
        "Choose (Add) to setup a new service<BR>",
        "Choose (Link to existing) to link to a legacy (pre-Freeside) service",
        "</FONT>"
  ;
}

#formatting
print <<END;
  </BODY>
</HTML>
END

