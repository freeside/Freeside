<%

my $svcpart = $cgi->param('svcpart');

my $old = qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

$cgi->param( 'svc_acct__usergroup',
             join(',', $cgi->param('svc_acct__usergroup') ) );

my $new = new FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } ( fields('part_svc'),
      map { my $svcdb = $_;
            my @fields = fields($svcdb);
            push @fields, 'usergroup' if $svcdb eq 'svc_acct'; #kludge
            map { ( $svcdb.'__'.$_, $svcdb.'__'.$_.'_flag' )  } @fields;
          } grep defined( $FS::Record::dbdef->table($_) ),
                 qw( svc_acct svc_domain svc_forward svc_www svc_broadband )
    )
} );

my $error;
if ( $svcpart ) {
  $error = $new->replace($old, '1.3-COMPAT', [ 'usergroup' ] );
} else {
  $error = $new->insert( [ 'usergroup' ] );
  $svcpart=$new->getfield('svcpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_svc.cgi?". $cgi->query_string );
} else {

  #false laziness w/ edit/process/agent_type.cgi
  foreach my $part_export (qsearch('part_export',{})) {
    my $exportnum = $part_export->exportnum;
    my $export_svc = qsearchs('export_svc', {
      'exportnum' => $part_export->exportnum,
      'svcpart'   => $new->svcpart,
    } );
    if ( $export_svc && ! $cgi->param("exportnum". $part_export->exportnum) ) {
      $error = $export_svc->delete;
      die $error if $error;
    } elsif ( $cgi->param("exportnum". $part_export->exportnum)
              && ! $export_svc ) {
      $export_svc = new FS::export_svc ( {
        'exportnum' => $part_export->exportnum,
        'svcpart'   => $new->svcpart,
      } );
      $error = $export_svc->insert;
      die $error if $error;
    }

  }

  print $cgi->redirect(popurl(3)."browse/part_svc.cgi");
}

%>
