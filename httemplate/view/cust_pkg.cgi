<%
# <!-- $Id: cust_pkg.cgi,v 1.4 2001-10-26 10:24:56 ivan Exp $ -->

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
print $cgi->header( @FS::CGI::header ), header('Package View', menubar(
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

print <<END;
<SCRIPT>
function areyousure(href) {
    if (confirm("Permanantly delete included services and cancel this package?") == true)
        window.location.href = href;
}
</SCRIPT>
END

print "Package information";
print ' (<A HREF="'. popurl(2). 'misc/unsusp_pkg.cgi?'. $pkgnum.
      '">unsuspend</A>)'
  if ( $susp && ! $cancel );

print ' (<A HREF="'. popurl(2). 'misc/susp_pkg.cgi?'. $pkgnum.
      '">suspend</A>)'
  unless ( $susp || $cancel );

print ' (<A HREF="javascript:areyousure(\''. popurl(2). 'misc/cancel_pkg.cgi?'.
      $pkgnum.  '\')">cancel</A>)'
  unless $cancel;

print ' (<A HREF="'. popurl(2). 'edit/REAL_cust_pkg.cgi?'. $pkgnum.
      '">edit dates</A>)';

print &ntable("#cccccc"), '<TR><TD>', &ntable("#cccccc",2),
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
  print '<BR>Service Information', &table();

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

%>
