% if ( $error ) {
%   errorpage($error);
%  } else {
    <% include('/elements/header.html','Import successful') %> 
    <% include('/elements/footer.html') %> 
%  }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $fh = $cgi->upload('csvfile');
#warn $cgi;
#warn $fh;

my $error = defined($fh)
  ? FS::cust_main::batch_import( {
      filehandle => $fh,
      agentnum   => scalar($cgi->param('agentnum')),
      refnum     => scalar($cgi->param('refnum')),
      pkgpart    => scalar($cgi->param('pkgpart')),
      #'fields'    => [qw( cust_pkg.setup dayphone first last address1 address2
      #                   city state zip comments                          )],
      'format'   => scalar($cgi->param('format')),
    } )
  : 'No file';

</%init>
