#!/usr/bin/perl -Tw
#
# $Id: agent_type.cgi,v 1.7 1999-01-25 12:09:58 ivan Exp $
#
# ivan@sisd.com 97-dec-11
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: agent_type.cgi,v $
# Revision 1.7  1999-01-25 12:09:58  ivan
# yet more mod_perl stuff
#
# Revision 1.6  1999/01/19 05:13:48  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 22:47:50  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.4  1998/12/30 23:03:27  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.3  1998/12/17 08:40:17  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/21 07:49:20  ivan
# s/CGI::Request/CGI.pm/
#

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

