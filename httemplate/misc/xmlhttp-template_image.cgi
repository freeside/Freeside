<%doc>
Returns JSON encoded array of objects with details about FS::template_image
objects.  Attributes in each returned object are imgnum, name, and src.

Accepts the following options:

imgnum - only return object for this imgnum

no_src - do not include the src field

</%doc>
<% encode_json(\@result) %>\
<%init>
use FS::template_image;

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right([ 'View templates', 'View global templates',
                                  'Edit templates', 'Edit global templates', ]);

my %arg = $cgi->param('arg');

my $search = {
  'table' => 'template_image',
  'hashref' => {},
};

my $imgnum = $arg{'imgnum'} || '';
die "Bad imgnum" unless $imgnum =~ /^\d*$/;
$search->{'hashref'}->{'imgnum'} = $imgnum if $imgnum;

$search->{'select'} = 'imgnum, name' if $arg{'no_src'};

$search->{'extra_sql'} = ($imgnum ? ' AND ' : ' WHERE ')
                       . $curuser->agentnums_sql(
                           'null_right' => ['View global templates','Edit global templates']
                         );

my @images = qsearch($search); #needs agent virtualization

my @result = map { +{
  'imgnum' => $_->imgnum,
  'name'   => $_->name,
  'src'    => $arg{'no_src'} ? '' : $_->src,
} } @images;

</%init>
