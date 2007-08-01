<% $data %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;

my $type;
if ( $cgi->param('type') eq 'png' ) {
  $type = 'png';
} elsif ( $cgi->param('type') eq 'eps' ) {
  $type = 'eps';
} else {
  die "unknown logo type ". $cgi->param('type');
}

my $data;
if ( $cgi->param('preview_session') =~ /^(\w+)$/ ) {

  my $session = $1;
  my $curuser = $FS::CurrentUser::CurrentUser;
  $data = decode_base64( $curuser->option("logo_preview$session") );

} elsif ( $cgi->param('name') =~ /^([^\.\/]*)$/ ) {

  my $templatename = $1;
  if ( $templatename && $conf->exists("logo_$templatename.$type") ) {
    $templatename = "_$templatename";
  } else {
    $templatename = '';
  }

  if ( $type eq 'png' ) {
    $data = $conf->config_binary("logo$templatename.png");
  } elsif ( $type eq 'eps' ) {
    #convert EPS to a png... punting on that for now
  }

} else {
  die "neither a valid name nor a valid preview_session specified";
}

http_header('Content-Type' => 'image/png' );

</%init>

