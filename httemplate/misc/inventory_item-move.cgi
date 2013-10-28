<% '',$cgi->redirect(popurl(2). "search/inventory_item.html?$browse_opts") %>
<%init>
die "access denied" unless $FS::CurrentUser::CurrentUser->access_right(
    [ 'Edit inventory', 'Edit global inventory' ]
  );


my $browse_opts = join(';', map { $_.'='.$cgi->param($_) }
    qw( classnum avail )
    );


my $move_agentnum;
if ( $cgi->param('move') ) {
 $move_agentnum = $cgi->param('move_agentnum') or 
    die "No agent selected";
} elsif ( $cgi->param('delete') ) {
  # don't need it in this case
} else {
  die "No action selected";
}

foreach my $itemnum ( grep /^\d+$/, $cgi->param('itemnum') )
{
  my $item = FS::inventory_item->by_key($itemnum) or next;
#  UI disallows this
#  die "Can't move assigned inventory item $itemnum" if $item->svcnum;
  my $error;
  if ( $cgi->param('move') ) {
    $item->agentnum($move_agentnum);
    $error = $item->replace;
  } elsif ( $cgi->param('delete') ) {
    $error = $item->delete;
  }
  die $error if $error;
}

</%init>

