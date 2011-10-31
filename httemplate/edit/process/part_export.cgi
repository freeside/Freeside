%if ( $error ) {
%  $cgi->param('error', $error );
<% $cgi->redirect(popurl(2). "part_export.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "browse/part_export.cgi") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $exportnum = $cgi->param('exportnum');

my $old = qsearchs('part_export', { 'exportnum'=>$exportnum } ) if $exportnum;

#fixup options
#warn join('-', split(',',$cgi->param('options')));
my %options = map {
  my @values = $cgi->param($_);
  my $value = scalar(@values) > 1 ? join (' ', @values) : $values[0];
  $value =~ s/\r\n/\n/g; #browsers? (textarea)
  $_ => $value;
} split(',', $cgi->param('options'));

my $new = new FS::part_export ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_export')
} );

my $error;
if ( $exportnum ) {
  #warn $old;
  #warn $exportnum;
  #warn $new->machine;
  $error = $new->replace($old,\%options);
} else {
  $error = $new->insert(\%options);
#  $exportnum = $new->exportnum;
}

my $info = FS::part_export::export_info()->{$new->exporttype};
if ( $info->{nas} ) {
  my @nasnums = map { /^nasnum(\d+)$/ ? $1 : () } keys %{ $cgi->Vars };
  $error ||= $new->process_m2m(
    link_table    => 'export_nas',
    target_table  => 'nas',
    params        => \@nasnums
  );
}

</%init>
