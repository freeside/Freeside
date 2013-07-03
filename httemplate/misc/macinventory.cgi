<% encode_json(\@macs) %>\
<%init>

# XXX: this should be agent-virtualized / limited

my $devicepart = $cgi->param('arg');

die 'invalid devicepart' unless $devicepart =~ /^\d+$/;

my $part_device = qsearchs('part_device', { 'devicepart' => $devicepart } );
die "unknown devicepart $devicepart" unless $part_device;

my $inventory_class = $part_device->inventory_class;
die "devicepart $devicepart has no inventory" unless $inventory_class;

my @macs =
  map $_->item,
    qsearch('inventory_item', { 'classnum' => $inventory_class->classnum } );

</%init>
