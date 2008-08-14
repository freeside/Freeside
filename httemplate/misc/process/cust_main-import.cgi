% if ( $error ) {
%   errorpage($error);
%  } else {
    <% include('/elements/header.html','Import successful') %> 
    <% include('/elements/footer.html') %> 
%  }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $fh = $cgi->upload('file');
my $error = '';
if ( defined($fh) ) {

  my $type;
  if ( $cgi->param('file') =~ /\.(\w+)$/i ) {
    $type = lc($1);
  } else {
    #or error out???
    warn "can't parse file type from filename ". $cgi->param('file').
         '; defaulting to CSV';
    $type = 'csv';
  }

  $error =
    FS::cust_main::batch_import( {
      filehandle => $fh,
      type       => $type,
      agentnum   => scalar($cgi->param('agentnum')),
      refnum     => scalar($cgi->param('refnum')),
      pkgpart    => scalar($cgi->param('pkgpart')),
      #'fields'    => [qw( cust_pkg.setup dayphone first last address1 address2
      #                    city state zip comments                          )],
      'format'   => scalar($cgi->param('format')),
    } );

} else {
  $error = 'No file';
}

</%init>
