<% $cgi->redirect(popurl(3). "search/cust_pay.html?magic=paybatch;paybatch=$paybatch") %> 
<%init>

my $fh = $cgi->upload('csvfile');

# webbatch?  I suppose
my $paybatch = time2str('webbatch-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);

my $error = defined($fh)
  ? FS::cust_pay::batch_import( {
      'filehandle' => $fh,
      'agentnum'   => scalar($cgi->param('agentnum')),
      'format'     => scalar($cgi->param('format')),
      'paybatch'   => $paybatch,
    } )
  : 'No file';

errorpage($error)
  if ( $error );

</%init>
