%
%
%  my $fh = $cgi->upload('csvfile');
%  #warn $cgi;
%  #warn $fh;
%
%  my $error = defined($fh)
%    ? FS::cust_main::batch_import( {
%        filehandle => $fh,
%        agentnum   => scalar($cgi->param('agentnum')),
%        refnum     => scalar($cgi->param('refnum')),
%        pkgpart    => scalar($cgi->param('pkgpart')),
%        #'fields'    => [qw( cust_pkg.setup dayphone first last address1 address2
%        #                   city state zip comments                          )],
%        'format'   => scalar($cgi->param('format')),
%      } )
%    : 'No file';
%
%  if ( $error ) {
%    

    <!-- mason kludge -->
%
%    eidiot($error);
%#    $cgi->param('error', $error);
%#    print $cgi->redirect( "${p}cust_main-import.cgi
%  } else {
%    

    <!-- mason kludge -->
    <% include("/elements/header.html",'Import successful') %> 
%
%  }
%

