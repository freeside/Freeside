<!-- mason kludge -->
<%

my $conf = new FS::Conf;

my %uiview = ();
my %uiadd = ();
foreach my $part_svc ( qsearch('part_svc',{}) ) {
  $uiview{$part_svc->svcpart} = popurl(2). "view/". $part_svc->svcdb . ".cgi";
  $uiadd{$part_svc->svcpart}= popurl(2). "edit/". $part_svc->svcdb . ".cgi";
}

my ($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $pkgnum = $1;

#get package record
my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
die "No package!" unless $cust_pkg;
my $part_pkg = qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->getfield('pkgpart')});

my $custnum = $cust_pkg->getfield('custnum');
print header('Package View', menubar(
  "View this customer (#$custnum)" => popurl(2). "view/cust_main.cgi?$custnum",
  'Main Menu' => popurl(2)
));

#print info
my ($susp,$cancel,$expire)=(
  $cust_pkg->getfield('susp'),
  $cust_pkg->getfield('cancel'),
  $cust_pkg->getfield('expire'),
);
my($pkg,$comment)=($part_pkg->getfield('pkg'),$part_pkg->getfield('comment'));
my($setup,$bill)=($cust_pkg->getfield('setup'),$cust_pkg->getfield('bill'));
my $otaker = $cust_pkg->getfield('otaker');

print <<END;
<SCRIPT>
function areyousure(href) {
    if (confirm("Permanently delete included services and cancel this package?") == true)
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
      ( $setup ? time2str("%D",$setup) : "(Not setup)" ), '</TD></TR>';

print '<TR><TD ALIGN="right">Last bill date</TD><TD BGCOLOR="#ffffff">',
      ( $cust_pkg->last_bill ? time2str("%D",$cust_pkg->last_bill) : "&nbsp;" ),
      '</TD></TR>'
  if $cust_pkg->dbdef_table->column('last_bill');

print '<TR><TD ALIGN="right">Next bill date</TD><TD BGCOLOR="#ffffff">',
      ( $bill ? time2str("%D",$bill) : "&nbsp;" ), '</TD></TR>';
      
print '<TR><TD ALIGN="right">Suspension date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$susp), '</TD></TR>' if $susp;
print '<TR><TD ALIGN="right">Expiration date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$expire), '</TD></TR>' if $expire;
print '<TR><TD ALIGN="right">Cancellation date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$cancel), '</TD></TR>' if $cancel;
print  '<TR><TD ALIGN="right">Order taker</TD><TD BGCOLOR="#ffffff">',
      $otaker,  '</TD></TR>',
      '</TABLE></TD></TR></TABLE>';

unless ($expire) {
  print <<END;
<FORM ACTION="../misc/expire_pkg.cgi" METHOD="post">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
Expire (date): <INPUT TYPE="text" NAME="date" VALUE="" >
<INPUT TYPE="submit" VALUE="Cancel later">
END
}

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
<TR><TD><A HREF="$uiview{$svcpart}?$svcnum">(View/Edit) $svc: $value<A></TD></TR>
END
      } else {
        print qq!<TR><TD>!.
              qq!<A HREF="$uiadd{$svcpart}?pkgnum$pkgnum-svcpart$svcpart">!.
              qq!(Provision) $svc</A>!;

        print qq! or <A HREF="../misc/link.cgi?pkgnum$pkgnum-svcpart$svcpart">!.
              qq!(Link to legacy) $svc</A>!
          if $conf->exists('legacy_link');

        print '</TD></TR>';
      }

    }
    warn "WARNING: Leftover services pkgnum $pkgnum!" if @cust_svc;; 
  }

  print "</TABLE><FONT SIZE=-1>",
        "Choose (View/Edit) to view or edit an existing service<BR>",
        "Choose (Provision) to setup a new service<BR>";

  print "Choose (Link to legacy) to link to a legacy (pre-Freeside) service"
    if $conf->exists('legacy_link');

  print "</FONT>";
}

#formatting
print <<END;
  </BODY>
</HTML>
END

%>
