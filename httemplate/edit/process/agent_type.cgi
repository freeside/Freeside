<%

my $typenum = $cgi->param('typenum');
my $old = qsearchs('agent_type',{'typenum'=>$typenum}) if $typenum;

my $new = new FS::agent_type ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('agent_type')
} );

my $error;
if ( $typenum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $typenum=$new->getfield('typenum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "agent_type.cgi?". $cgi->query_string );
} else {

  #false laziness w/ edit/process/part_svc.cgi
  foreach my $part_pkg (qsearch('part_pkg',{})) {
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
}

%>
