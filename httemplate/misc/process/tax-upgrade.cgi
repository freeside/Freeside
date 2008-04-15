% if ( $error ) {
%   warn $error;
%   errorpage($error);
%  } else {
    <% include('/elements/header.html','Import successful') %> 
    <% include('/elements/footer.html') %> 
%  }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $cfh = $cgi->upload('codefile');
my $zfh = $cgi->upload('plus4file');
my $tfh = $cgi->upload('txmatrix');
my $dfh = $cgi->upload('detail');
#warn $cgi;
#warn $fh;

my $oldAutoCommit = $FS::UID::AutoCommit;
local $FS::UID::AutoCommit = 0;
my $dbh = dbh;

my $error = '';

my ($cifh, $cdfh, $zifh, $zdfh, $tifh, $tdfh);

if (defined($cfh)) {
  $cifh = new File::Temp( TEMPLATE => 'code.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  $cdfh = new File::Temp( TEMPLATE => 'code.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  while(<$cfh>) {
    my $fh = '';
    $fh = $cifh if $_ =~ /"I"\s*$/;
    $fh = $cdfh if $_ =~ /"D"\s*$/;
    die "bad input line: $_" unless $fh;
    print $fh $_;
  }
  seek $cifh, 0, 0;
  seek $cdfh, 0, 0;

}else{
  $error = 'No code file';
}

$error ||= FS::tax_class::batch_import( {
             filehandle => $cifh,
             'format'   => scalar($cgi->param('format')),
           } );

close $cifh if $cifh;

if (defined($zfh)) {
  $zifh = new File::Temp( TEMPLATE => 'plus4.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  $zdfh = new File::Temp( TEMPLATE => 'plus4.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  while(<$zfh>) {
    my $fh = '';
    $fh = $zifh if $_ =~ /"I"\s*$/;
    $fh = $zdfh if $_ =~ /"D"\s*$/;
    die "bad input line: $_" unless $fh;
    print $fh $_;
  }
  seek $zifh, 0, 0;
  seek $zdfh, 0, 0;

}else{
  $error = 'No plus4 file';
}

$error ||= FS::cust_tax_location::batch_import( {
             filehandle => $zifh,
             'format'   => scalar($cgi->param('format')),
           } );
close $zifh if $zifh;

if (defined($tfh)) {
  $tifh = new File::Temp( TEMPLATE => 'txmatrix.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  $tdfh = new File::Temp( TEMPLATE => 'txmatrix.insert.XXXXXXXX',
                          DIR      => $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc,
                        ) or die "can't open temp file: $!\n";

  while(<$tfh>) {
    my $fh = '';
    $fh = $tifh if $_ =~ /"I"\s*$/;
    $fh = $tdfh if $_ =~ /"D"\s*$/;
    die "bad input line: $_" unless $fh;
    print $fh $_;
  }
  seek $tifh, 0, 0;
  seek $tdfh, 0, 0;

}else{
  $error = 'No tax matrix file';
}

$error ||= FS::part_pkg_taxrate::batch_import( {
             filehandle => $tifh,
             'format'   => scalar($cgi->param('format')),
           } );
close $tifh if $tifh;

$error ||= defined($dfh)
  ? FS::tax_rate::batch_update( {
      filehandle => $dfh,
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No tax detail file';

$error ||= FS::part_pkg_taxrate::batch_import( {
             filehandle => $tdfh,
             'format'   => scalar($cgi->param('format')),
           } );
close $tdfh if $tdfh;

$error ||= FS::cust_tax_location::batch_import( {
             filehandle => $zdfh,
             'format'   => scalar($cgi->param('format')),
           } );
close $zdfh if $zdfh;

$error ||= FS::tax_class::batch_import( {
             filehandle => $cdfh,
             'format'   => scalar($cgi->param('format')),
           } );
close $cdfh if $cdfh;

if ($error) {
  $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
}else{
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}

</%init>
