<%
#<!-- $Id: cust_pkg.cgi,v 1.3 2001-10-26 10:24:56 ivan Exp $ -->

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
print $cgi->header( @FS::CGI::header ), header("Add/Edit Packages", '');

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
%>
