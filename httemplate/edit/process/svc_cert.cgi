%if ( $popup ) {
%  if ( $error ) { #should redirect back to the posting page?
<% include("/elements/header-popup.html", "Error") %>
<P><FONT SIZE="+1" COLOR="#ff0000"><% $error |h %></FONT>
<BR><BR>
<P ALIGN="center">
<BUTTON TYPE="button" onClick="parent.cClick();">Close</BUTTON>
</BODY></HTML>
%  } else {
<% include('/elements/header-popup.html', $title ) %>
    <SCRIPT TYPE="text/javascript">
      window.top.location = '<% popurl(3). "edit/svc_cert.cgi?$svcnum" %>';
    </SCRIPT>
    </BODY></HTML>
%  }
%} elsif ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "svc_cert.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_cert.cgi?$svcnum") %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $new = new FS::svc_cert ( {
  map {
    $_, scalar($cgi->param($_));
  } ( fields('svc_cert'), qw( pkgnum svcpart ) )
} );

my $old = '';
if ( $svcnum ) {
  $old = qsearchs('svc_cert', { 'svcnum' => $svcnum } ) #agent virt;
    or die 'unknown svcnum';
  $new->$_( $old->$_ ) for grep $old->$_, qw( privatekey csr certificate cacert );
}

my $popup = 0;
my $title = '';
if ( $cgi->param('privatekey') eq '_generate' ) { #generate
  $popup = 1;
  $title = 'Key generated';

  $cgi->param('keysize') =~ /^(\d+)$/ or die 'illegal keysize';
  my $keysize = $1;
  $new->generate_privatekey($keysize);

} elsif ( $cgi->param('privatekey') =~ /\S/ ) { #import
  $popup = 1;
  $title = 'Key imported';

  $new->privatekey( $cgi->param('privatekey') );

} #elsif ( $cgi->param('privatekey') eq '_clear' ) { #clear

my $error = '';
if ($cgi->param('svcnum')) {
  $error  = $new->replace();
} else {
  $error  = $new->insert;
  $svcnum = $new->svcnum;
}

</%init>
