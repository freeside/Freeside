%
%
%my $exportnum = $cgi->param('exportnum');
%
%my $old = qsearchs('part_export', { 'exportnum'=>$exportnum } ) if $exportnum;
%
%#fixup options
%#warn join('-', split(',',$cgi->param('options')));
%my %options = map {
%  my $value = $cgi->param($_);
%  $value =~ s/\r\n/\n/g; #browsers? (textarea)
%  $_ => $value;
%} split(',', $cgi->param('options'));
%
%my $new = new FS::part_export ( {
%  map {
%    $_, scalar($cgi->param($_));
%  } fields('part_export')
%} );
%
%my $error;
%if ( $exportnum ) {
%  #warn $old;
%  #warn $exportnum;
%  #warn $new->machine;
%  $error = $new->replace($old,\%options);
%} else {
%  $error = $new->insert(\%options);
%#  $exportnum = $new->exportnum;
%}
%
%if ( $error ) {
%  $cgi->param('error', $error );
%  print $cgi->redirect(popurl(2). "part_export.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "browse/part_export.cgi");
%}
%
%

