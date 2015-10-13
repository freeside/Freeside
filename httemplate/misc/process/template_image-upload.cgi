<% $server->process %>

<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right([ 'Edit templates', 'Edit global templates' ]);

my %arg = $cgi->param('arg');
my $agentnum = $arg{'agentnum'};

if (!$agentnum) {
  die "access denied"
    unless $curuser->access_right([ 'Edit global templates' ]);
} else {
  die "bad agentnum"
    unless $agentnum =~ /^\d+$/;
  die "access denied"
    unless $curuser->agentnum($agentnum);
}

my $server =
  new FS::UI::Web::JSRPC 'FS::template_image::process_image_upload', $cgi;

</%init>
