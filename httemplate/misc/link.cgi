<%
#<!-- $Id: link.cgi,v 1.4 2001-10-30 14:54:07 ivan Exp $ -->

use strict;
use vars qw ( %link_field $cgi $pkgnum $svcpart $query $part_svc $svc $svcdb 
              $link_field );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl header);
use FS::Record qw(qsearchs);

%link_field = (
  'svc_acct'    => 'username',
  'svc_domain'  => 'domain',
  'svc_acct_sm' => '',
  'svc_charge'  => '',
  'svc_wo'      => '',
);

$cgi = new CGI;
cgisuidsetup($cgi);

($query) = $cgi->keywords;
foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
  $pkgnum=$1 if /^pkgnum(\d+)$/;
  $svcpart=$1 if /^svcpart(\d+)$/;
}

$part_svc = qsearchs('part_svc',{'svcpart'=>$svcpart});
$svc = $part_svc->getfield('svc');
$svcdb = $part_svc->getfield('svcdb');
$link_field = $link_field{$svcdb};

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
