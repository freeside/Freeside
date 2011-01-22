<% objToJson(\@macs) %>
<%init>

# XXX: this should be agent-virtualized / limited

my $devicepart = $cgi->param('arg');

die 'invalid devicepart' unless $devicepart =~ /^\d+$/;

my $part_device = qsearchs('part_device', { 'devicepart' => $devicepart } );
die "unknown devicepart $devicepart" unless $part_device;

my $inventory_class = $part_device->inventory_class;
die "devicepart $devicepart has no inventory" unless $inventory_class;

my @inventory_item =
    qsearch('inventory_item', { 'classnum' => $inventory_class->classnum } );

my @macs;

foreach my $inventory_item ( @inventory_item ) {
    push @macs, $inventory_item->item;
}

</%init>
