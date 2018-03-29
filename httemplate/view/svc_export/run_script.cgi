<% $server->process %>
<%init>

my @args = $cgi->param('arg');
my %param = ();
  while ( @args ) {
    my( $field, $value ) = splice(@args, 0, 2);
    unless ( exists( $param{$field} ) ) {
      $param{$field} = $value;
    } elsif ( ! ref($param{$field}) ) {
      $param{$field} = [ $param{$field}, $value ];
    } else {
      push @{$param{$field}}, $value;
    }
  }

my $exportnum;
my $method;
for (grep /^*_script$/, keys %param) { 
	$exportnum = $param{$param{$_}.'_exportnum'};
	$method = $param{$param{$_}.'_script'};
}

my $part_export = qsearchs('part_export', { 'exportnum'=> $exportnum, } )
	or die "unknown exportnum $exportnum";

my $class = 'FS::part_export::'.$part_export->{Hash}->{exporttype}.'::'.$method;

my $server = new FS::UI::Web::JSRPC $class, $cgi;

</%init>