% if ( $error ) {
0,"<% $error %>",,
% } else {
1,"CDR import successful",<% $cdr_batch->cdrbatchnum %>,"<% $cdrbatch %>"
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $error = '';
my $cdr_batch;
my $cdrbatch = '';

{

  my $filename = $cgi->param('cdr_file');
  unless ( $filename ) {
    $error = "No cdr_file filename";
    last;
  }

  my $fh = $cgi->upload('cdr_file');
  unless ( defined($fh) ) {
    $error = 'No cdr_file file';
    last;
  }

  #i should probably be transactionalized.

  my $csv = new Text::CSV_XS or die Text::CSV->error_diag;

  $cdrbatch = time2str('post-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);
  $cdr_batch = new FS::cdr_batch { 'cdrbatch' => $cdrbatch };
  $error = $cdr_batch->insert and last;

  chomp(my $hline = scalar(<$fh>));
  $csv->parse($hline);
  my @header = $csv->fields;

  #while ( my $row = $csv->getline($fh) ) {
  while (<$fh>) {

    $csv->parse($_);
    my @row = $csv->fields;

    my $cdr = new FS::cdr { 'cdrbatchnum' => $cdr_batch->cdrbatchnum };
    $cdr->set( lc($_) => shift(@row) ) foreach @header;

    $error = $cdr->insert and last;

  }

}

$error =~ s/"/""/g; #CSV

</%init>
