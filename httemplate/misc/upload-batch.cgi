<%

  my $fh = $cgi->upload('batch_results');
  my $filename = $cgi->param('batch_results');
  my $paybatch = basename($filename);

  my $error = defined($fh)
    ? FS::cust_pay_batch::import_results( {
        'filehandle' => $fh,
        'format'     => $cgi->param('format'),
        'paybatch'   => $paybatch,
      } )
    : 'No file';

  if ( $error ) {
    %>
    <!-- mason kludge -->
    <%
    eidiot($error);
#    $cgi->param('error', $error);
#    print $cgi->redirect( "${p}cust_main-import.cgi
  } else {
    %>
    <!-- mason kludge -->
    <%= header('Batch results upload sucessful') %> <%
  }
%>

