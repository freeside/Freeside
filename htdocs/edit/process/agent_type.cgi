#!/usr/bin/perl -Tw
#
# process/agent_type.cgi: Edit agent type (process form)
#
# ivan@sisd.com 97-dec-11
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::agent_type qw(fields);
use FS::type_pkgs;
use FS::CGI qw(idiot);

my($req)=new CGI::Request;
&cgisuidsetup($req->cgi);

my($typenum)=$req->param('typenum');
my($old)=qsearchs('agent_type',{'typenum'=>$typenum}) if $typenum;

my($new)=create FS::agent_type ( {
  map {
    $_, $req->param($_);
  } fields('agent_type')
} );

my($error);
if ( $typenum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $typenum=$new->getfield('typenum');
}

if ( $error ) {
  idiot($error);
  exit;
}

my($part_pkg);
foreach $part_pkg (qsearch('part_pkg',{})) {
  my($pkgpart)=$part_pkg->getfield('pkgpart');

  my($type_pkgs)=qsearchs('type_pkgs',{
      'typenum' => $typenum,
      'pkgpart' => $pkgpart,
  });
  if ( $type_pkgs && ! $req->param("pkgpart$pkgpart") ) {
    my($d_type_pkgs)=$type_pkgs; #need to save $type_pkgs for below.
    $error=$d_type_pkgs->del; #FS::Record not FS::type_pkgs,
                                  #so ->del not ->delete.  hmm.  hmm.
    if ( $error ) {
      idiot($error);
      exit;
    }

  } elsif ( $req->param("pkgpart$pkgpart")
            && ! $type_pkgs
  ) {
    #ok to clobber it now (but bad form nonetheless?)
    $type_pkgs=create FS::type_pkgs ({
      'typenum' => $typenum,
      'pkgpart' => $pkgpart,
    });
    $error= $type_pkgs->insert;
    if ( $error ) {
      idiot($error);
      exit;
    }
  }

}

#$req->cgi->redirect("../../view/agent_type.cgi?$typenum");
#$req->cgi->redirect("../../edit/agent_type.cgi?$typenum");
$req->cgi->redirect("../../browse/agent_type.cgi");

