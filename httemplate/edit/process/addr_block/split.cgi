<% $cgi->redirect(popurl(4). "browse/addr_block.cgi?". $cgi->query_string ) %>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Broadband configuration')
      || $curuser->access_right('Broadband global configuration');

my $error = '';
$cgi->param('blocknum') =~ /^(\d+)$/ or die "invalid blocknum";
my $blocknum = $1;

my $addr_block = qsearchs({ 'table'     => 'addr_block',
                            'hashref'   => { blocknum => $blocknum },
                            'extra_sql' => ' AND '. $curuser->agentnums_sql(
                              'null_right' => 'Broadband global configuration'
                            ),
                         })
  or $error = "Unknown blocknum: $blocknum";

$error ||= $addr_block->split_block;

$cgi->param('error', $error)
  if $error;

</%init>
