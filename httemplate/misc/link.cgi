<!-- mason kludge -->
<%

my %link_field = (
  'svc_acct'    => 'username',
  'svc_domain'  => 'domain',
  'svc_charge'  => '',
  'svc_wo'      => '',
);

my($query) = $cgi->keywords;
my($pkgnum, $svcpart) = ('', '');
foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
  $pkgnum=$1 if /^pkgnum(\d+)$/;
  $svcpart=$1 if /^svcpart(\d+)$/;
}

my $part_svc = qsearchs('part_svc',{'svcpart'=>$svcpart});
my $svc = $part_svc->getfield('svc');
my $svcdb = $part_svc->getfield('svcdb');
my $link_field = $link_field{$svcdb};

print header("Link to existing $svc"),
      qq!<FORM ACTION="!, popurl(1), qq!process/link.cgi" METHOD=POST>!;

if ( $link_field ) { 
  print <<END;
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="">
  <INPUT TYPE="hidden" NAME="link_field" VALUE="$link_field">
  $link_field of existing service: <INPUT TYPE="text" NAME="link_value">
END
} else {
  print qq!Service # of existing service: <INPUT TYPE="text" NAME="svcnum" VALUE="">!;
}

print <<END;
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
<P><CENTER><INPUT TYPE="submit" VALUE="Link"></CENTER>
    </FORM>
  </BODY>
</HTML>
END

%>
