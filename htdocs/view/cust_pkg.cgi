#!/usr/bin/perl -Tw
#
# $Id: cust_pkg.cgi,v 1.3 1998-12-17 09:57:22 ivan Exp $
#
# Usage: cust_pkg.cgi pkgnum
#        http://server.name/path/cust_pkg.cgi?pkgnum
#
# Note: Should be run setuid freeside as user nobody.
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
# Revision 1.3  1998-12-17 09:57:22  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/11/13 09:56:49  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use Date::Format;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl header);
use FS::Record qw(qsearch qsearchs);

my($cgi) = new CGI;
cgisuidsetup($cgi);

my(%uiview,%uiadd);
my($part_svc);
foreach $part_svc ( qsearch('part_svc',{}) ) {
  $uiview{$part_svc->svcpart} = popurl(2). "view/". $part_svc->svcdb . ".cgi";
  $uiadd{$part_svc->svcpart}= popurl(2). "edit/". $part_svc->svcdb . ".cgi";
}

print $cgi->header, header('Package View', '');

$cgi->query_string =~ /^(\d+)$/;
my($pkgnum)=$1;

#get package record
my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
die "No package!" unless $cust_pkg;
my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->getfield('pkgpart')});

#nav bar
my($custnum)=$cust_pkg->getfield('custnum');
print qq!<CENTER><A HREF="../view/cust_main.cgi?$custnum">View this customer!,
      qq! (#$custnum)</A> | <A HREF="../">Main menu</A></CENTER><BR>!;

#print info
my($susp,$cancel,$expire)=(
  $cust_pkg->getfield('susp'),
  $cust_pkg->getfield('cancel'),
  $cust_pkg->getfield('expire'),
);
print "<FONT SIZE=+1><CENTER>Package #<B>$pkgnum</B></FONT>";
print qq!<BR><A HREF="#package">Package Information</A>!;
print qq! | <A HREF="#services">Service Information</A>! unless $cancel;
print qq!</CENTER><HR>\n!;

my($pkg,$comment)=($part_pkg->getfield('pkg'),$part_pkg->getfield('comment'));
print qq!<A NAME="package"><CENTER><FONT SIZE=+1>Package Information!,
      qq!</FONT></A>!;
print qq!<BR><A HREF="../unimp.html">Edit this information</A></CENTER>!;
print "<P>Package: <B>$pkg - $comment</B>";

my($setup,$bill)=($cust_pkg->getfield('setup'),$cust_pkg->getfield('bill'));
print "<BR>Setup: <B>", $setup ? time2str("%D",$setup) : "(Not setup)" ,"</B>";
print "<BR>Next bill: <B>", $bill ? time2str("%D",$bill) : "" ,"</B>";

if ($susp) {
  print "<BR>Suspended: <B>", time2str("%D",$susp), "</B>";
  print qq! <A HREF="../misc/unsusp_pkg.cgi?$pkgnum">Unsuspend</A>! unless $cancel;
} else {
  print qq!<BR><A HREF="../misc/susp_pkg.cgi?$pkgnum">Suspend</A>! unless $cancel;
}

if ($expire) {
  print "<BR>Expire: <B>", time2str("%D",$expire), "</B>";
}
  print <<END;
<FORM ACTION="../misc/expire_pkg.cgi" METHOD="post">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
Expire (date): <INPUT TYPE="text" NAME="date" VALUE="" >
<INPUT TYPE="submit" VALUE="Cancel later">
END

if ($cancel) {
  print "<BR>Cancelled: <B>", time2str("%D",$cancel), "</B>";
} else {
  print qq!<BR><A HREF="../misc/cancel_pkg.cgi?$pkgnum">Cancel now</A>!;
}

#otaker
my($otaker)=$cust_pkg->getfield('otaker');
print "<P>Order taken by <B>$otaker</B>";

unless ($cancel) {

  #services
  print <<END;
<HR><A NAME="services"><CENTER><FONT SIZE=+1>Service Information</FONT></A>
<BR>Click on service to view/edit/add service.</CENTER><BR>
<CENTER><B>Do NOT pick the "Link to existing" option unless you are auditing!!!</B></CENTER>
<CENTER><TABLE BORDER=4>
<TR><TH>Service</TH>
END

  #list of services this pkgpart includes
  my($pkg_svc,%pkg_svc);
  foreach $pkg_svc ( qsearch('pkg_svc',{'pkgpart'=> $cust_pkg->pkgpart }) ) {
    $pkg_svc{$pkg_svc->svcpart} = $pkg_svc->quantity if $pkg_svc->quantity;
  }

  #list of records from cust_svc
  my($svcpart);
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
        print <<END;
<TR><TD><A HREF="$uiview{$svcpart}?$svcnum">(View) $svc<A></TD></TR>
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

  print "</TABLE></CENTER>";

}

#formatting
print <<END;
  </BODY>
</HTML>
END

