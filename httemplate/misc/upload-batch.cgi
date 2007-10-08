%  if ( $error ) {

    <!-- mason kludge -->

%    errorpage($error);
%#    $cgi->param('error', $error);
%#    print $cgi->redirect( "${p}cust_main-import.cgi
%  } else {

    <% include("/elements/header.html",'Batch results upload successful') %> 

%  }
<%init>

my $error;

my $fh = $cgi->upload('batch_results');
$error = 'No file uploaded' unless defined($fh);

unless ( $error ) {

  $cgi->param('batchnum') =~ /^(\d+)$/;
  my $batchnum = $1;

  my $pay_batch = qsearchs( 'pay_batch', { 'batchnum' => $batchnum } );
  if ( ! $pay_batch ) {
    $error = "batchnum $batchnum not found";
  } elsif ( $pay_batch->status ne 'I' ) {
    $error = "batch $batchnum is not in transit";
  } else {
    $error = $pay_batch->import_results(
                                         'filehandle' => $fh,
                                         'format'     => $cgi->param('format'),
                                       );
  }

}

</%init>
