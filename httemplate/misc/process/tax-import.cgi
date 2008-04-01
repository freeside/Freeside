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

my $error = defined($cfh)
  ? FS::tax_class::batch_import( {
      filehandle => $cfh,
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No code file';

$error ||= defined($zfh)
  ? FS::cust_tax_location::batch_import( {
      filehandle => $zfh,
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No plus4 file';

$error ||= defined($tfh)
  ? FS::part_pkg_taxrate::batch_import( {
      filehandle => $tfh,
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No tax matrix file';

$error ||= defined($dfh)
  ? FS::tax_rate::batch_import( {
      filehandle => $dfh,
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No tax detail file';

if ($error) {
  $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
}else{
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}

</%init>
