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
  ? FS::cust_main::batch_charge( {
      filehandle => $fh,
      'fields'    => [qw( custnum amount pkg )],
    } )
  : 'No file';

</%init>
