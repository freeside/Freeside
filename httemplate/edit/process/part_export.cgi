<%

my $dbh = dbh;

my $exportnum = $cgi->param('exportnum');

my $old = qsearchs('part_export', { 'exportnum'=>$exportnum } ) if $exportnum;

my $new = new FS::part_export ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_export')
} );

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';
local $SIG{PIPE} = 'IGNORE';

local $FS::UID::AutoCommit = 0;

my $error;
if ( $exportnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $exportnum = $new->exportnum;
}
if ( $error ) {
  $dbh->rollback;
  $cgi->param('error', $error );
  print $cgi->redirect(popurl(2). "part_export.cgi?". $cgi->query_string );
  myexit();
}

#options

$dbh->commit or die $dbh->errstr;
print $cgi->redirect(popurl(3). "browse/part_svc.cgi");

%>
