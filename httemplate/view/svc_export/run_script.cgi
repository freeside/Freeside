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

my $run_script = $param{'key'};
my $exportnum = $param{$run_script.'_exportnum'};

my $part_export = qsearchs('part_export', { 'exportnum'=> $exportnum, } )
	or die "unknown exportnum $exportnum";

my $class = 'FS::part_export::'.$part_export->{Hash}->{exporttype}.'::'.$run_script;

my $server = new FS::UI::Web::JSRPC $class, $cgi;

</%init>