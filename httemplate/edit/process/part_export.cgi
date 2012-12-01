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

my %vars = $cgi->Vars;
#fixup options
#warn join('-', split(',',$cgi->param('options')));
my %options = map {
  my $value = $vars{$_};
  $value =~ s/\0/ /g; # deal with multivalued options
  $value =~ s/\r\n/\n/g; #browsers? (textarea)
  $_ => $value;
} split(',', $cgi->param('options'));

# deal with multiline options
# %vars should never contain incomplete rows, but just in case it does, 
# we make a list of all the row indices that contain values, and 
# then write a line in each option for each row, even if it's empty.
# This ensures that all values with the same row index line up.
my %optionrows;
foreach my $option (split(',', $cgi->param('multi_options'))) {
  $optionrows{$option} = {};
  my %values; # bear with me
  for (keys %vars) {
    /^$option(\d+)/ or next;
    $optionrows{$option}{$1} = $vars{$option.$1};
    $optionrows{_ALL_}{$1} = 1 if length($vars{$option.$1});
  }
}
foreach my $option (split(',', $cgi->param('multi_options'))) {
  my $value = '';
  foreach my $row (sort keys %{$optionrows{_ALL_}}) {
    $value .= ($optionrows{$option}{$row} || '') . "\n";
  }
  chomp($value);
  $options{$option} = $value;
}

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
