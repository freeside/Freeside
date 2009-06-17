%unless ($error) {
%  #no errors, so let's view this customer.
%  my $custnum = $new->cust_pkg->custnum;
%  my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
%               ? ''
%               : ';show=packages';
%  my $frag = "cust_pkg$pkgnum"; #hack for IE ignoring real #fragment
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?custnum=$custnum$show;fragment=$frag#$frag" ) %>
%} else {
% errorpage($error);
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View/link unlinked services');

my $DEBUG = 0;

$cgi->param('pkgnum') =~ /^(\d+)$/;
my $pkgnum = $1;
$cgi->param('svcpart') =~ /^(\d+)$/;
my $svcpart = $1;
$cgi->param('svcnum') =~ /^(\d*)$/;
my $svcnum = $1;

unless ( $svcnum ) {
  my $part_svc = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my $svcdb = $part_svc->getfield('svcdb');
  $cgi->param('link_field') =~ /^(\w+)$/;
  my $link_field = $1;
  my %search = ( $link_field => $cgi->param('link_value') );
  if ( $cgi->param('link_field2') =~ /^(\w+)$/ ) {
    $search{$1} = $cgi->param('link_value2');
  }

  my @svc_x = ( sort { ($a->cust_svc->pkgnum > 0) <=> ($b->cust_svc->pkgnum > 0)
                       or ($b->cust_svc->svcpart == $svcpart)
                            <=> ($a->cust_svc->svcpart == $svcpart)
                     }
                     qsearch( $svcdb, \%search )
              );

  if ( $DEBUG ) {
    warn scalar(@svc_x). " candidate accounts found for linking ".
         "(svcpart $svcpart):\n";
    foreach my $svc_x ( @svc_x ) {
      warn "  ". $svc_x->email.
           " (svcnum ". $svc_x->svcnum. ",".
           " pkgnum ".  $svc_x->cust_svc->pkgnum. ",".
           " svcpart ". $svc_x->cust_svc->svcpart. ")\n";
    }
  }

  my $svc_x = $svc_x[0];

  errorpage("$link_field not found!") unless $svc_x;

  $svcnum = $svc_x->svcnum;

}

my $old = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "svcnum not found!" unless $old;
my $conf = new FS::Conf;
my($error, $new);
if ( $old->pkgnum && ! $conf->exists('legacy_link-steal') ) {
  $error = "svcnum $svcnum already linked to package ". $old->pkgnum;
} else {
  $new = new FS::cust_svc { $old->hash };
  $new->pkgnum($pkgnum);
  $new->svcpart($svcpart);

  $error = $new->replace($old);
}

</%init>
