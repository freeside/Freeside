<% '',$cgi->redirect(popurl(2). "search/inventory_item.html?$browse_opts") %>
<%init>

# Shamelessly copied from misc/cust_attachment.cgi.

my $browse_opts = join(';', map { $_.'='.$cgi->param($_) }
    qw( classnum avail )
    );

my $move_agentnum = $cgi->param('move_agentnum') or 
  die "No agent selected";
foreach my $itemnum (
  map { /^itemnum(\d+)$/; $1; } grep /^itemnum\d+$/, $cgi->param ) {
  my $item = qsearchs('inventory_item', { 'itemnum' => $itemnum });
#  die "Can't move assigned inventory item $itemnum" if $item->svcnum;
  my $error;
  $item->agentnum($move_agentnum);
  $error = $item->replace;
  die $error if $error;
}

</%init>

