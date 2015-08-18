<% $server->process %>

<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

# make sure user can generally edit
die "access denied"
  unless $curuser->access_right([ 'Edit templates', 'Edit global templates' ]);

# make sure user can edit this particular image
my %arg = $cgi->param('arg');
my $imgnum = $arg{'imgnum'};
die "bad imgnum" unless $imgnum =~ /^\d+$/;
die "access denied" unless qsearchs({
               'table'     => 'template_image',
               'select'    => 'imgnum',
               'hashref'   => { 'imgnum' => $imgnum },
               'extra_sql' => ' AND ' . 
                              $curuser->agentnums_sql(
                                'null_right' => ['Edit global templates']
                              ),
             });

my $server =
  new FS::UI::Web::JSRPC 'FS::template_image::process_image_delete', $cgi;

</%init>
