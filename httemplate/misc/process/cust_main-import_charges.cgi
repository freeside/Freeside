%
%
%  my $fh = $cgi->upload('csvfile');
%  #warn $cgi;
%  #warn $fh;
%
%  my $error = defined($fh)
%    ? FS::cust_main::batch_charge( {
%        filehandle => $fh,
%        'fields'    => [qw( custnum amount pkg )],
%      } )
%    : 'No file';
%
%  if ( $error ) {
%    

    <!-- mason kludge -->
%
% errorpage($error);
%#    $cgi->param('error', $error);
%#    print $cgi->redirect( "${p}cust_main-import_charges.cgi
%  } else {
%    

    <!-- mason kludge -->
    <% include("/elements/header.html",'Import successful') %> 
%
%  }
%

