<%

my $svcpart = $cgi->param('svcpart');

my $old = qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

my $new = new FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } ( fields('part_svc'),
      map { my $svcdb = $_;
            map { ( $svcdb.'__'.$_, $svcdb.'__'.$_.'_flag' )  }
              fields($svcdb)
          } grep defined( $FS::Record::dbdef->table($_) ),
                 qw( svc_acct svc_domain svc_acct_sm svc_forward svc_www )
    )
} );

my $error;
if ( $svcpart ) {
  $error = $new->replace($old, '1.3-COMPAT');
} else {
  $error = $new->insert;
  $svcpart=$new->getfield('svcpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2), "part_svc.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3)."browse/part_svc.cgi");
}

%>
