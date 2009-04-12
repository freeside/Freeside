<% objToJson(\@output) %>
<%init>

my $conf = new FS::Conf;

my $pkgpart_svcpart = $cgi->param('arg');
$pkgpart_svcpart =~ /^\d+_(\d+)$/;
my $part_svc = qsearchs('part_svc', { 'svcpart' => $1 }) if $1;

my @output = map { ( $_->columnname, $_->columnflag, $_->columnvalue ) }
                 $part_svc->all_part_svc_column;

</%init>
