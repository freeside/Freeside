<%
#<!-- $Id: agent_type.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw ( $cgi $typenum $old $new $error $part_pkg );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::CGI qw( popurl);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs fields);
use FS::agent_type;
use FS::type_pkgs;
use FS::part_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);

$typenum = $cgi->param('typenum');
$old = qsearchs('agent_type',{'typenum'=>$typenum}) if $typenum;

$new = new FS::agent_type ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent_type')
} );

if ( $typenum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $typenum=$new->getfield('typenum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "agent_type.cgi?". $cgi->query_string );
  exit;
}

foreach $part_pkg (qsearch('part_pkg',{})) {
  my($pkgpart)=$part_pkg->getfield('pkgpart');

  my($type_pkgs)=qsearchs('type_pkgs',{
      'typenum' => $typenum,
      'pkgpart' => $pkgpart,
  });
  if ( $type_pkgs && ! $cgi->param("pkgpart$pkgpart") ) {
    my($d_type_pkgs)=$type_pkgs; #need to save $type_pkgs for below.
    $error=$d_type_pkgs->delete;
    die $error if $error;

  } elsif ( $cgi->param("pkgpart$pkgpart")
            && ! $type_pkgs
  ) {
    #ok to clobber it now (but bad form nonetheless?)
    $type_pkgs=new FS::type_pkgs ({
      'typenum' => $typenum,
      'pkgpart' => $pkgpart,
    });
    $error= $type_pkgs->insert;
    die $error if $error;
  }

}

print $cgi->redirect(popurl(3). "browse/agent_type.cgi");

%>
