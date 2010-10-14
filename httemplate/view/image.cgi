<% $data %>\
<%init>

#die "access denied"
#  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;

my $type;
if ( $cgi->param('type') eq 'png' ) {
  $type = 'png';
} elsif ( $cgi->param('type') eq 'eps' ) {
  $type = 'eps';
} else {
  die "unknown image type ". $cgi->param('type');
}

my $data;
if ( $cgi->param('prefname') =~ /^(\w+)$/ ) {

  my $prefname = $1;
  my $curuser = $FS::CurrentUser::CurrentUser;
  $data = decode_base64( $curuser->option("$prefname") );

} else {
  die "no preview_session specified";
}

http_header('Content-Type' => 'image/png' );

</%init>
