%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "svc_domain.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

#remove this to actually test the domains!
$FS::svc_domain::whois_hack = 1;

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

#unmunge cgp_accessmodes (falze laziness-ish w/part_svc.pm::process & svc_acct)
unless ( $cgi->param('cgp_accessmodes') ) {
  $cgi->param('cgp_accessmodes', 
    join(' ',
      sort map { /^cgp_accessmodes_([\w\/]+)$/ or die "no way"; $1; }
               grep $cgi->param($_),
                    grep /^cgp_accessmodes_([\w\/]+)$/,
                         $cgi->param()
        )
  );
}

#unmunge acct_def_cgp_accessmodes (falze laziness-ahoy)
unless ( $cgi->param('acct_def_cgp_accessmodes') ) {
  $cgi->param('acct_def_cgp_accessmodes', 
    join(' ',
      sort map { /^acct_def_cgp_accessmodes_([\w\/]+)$/ or die "no way"; $1; }
               grep $cgi->param($_),
                    grep /^acct_def_cgp_accessmodes_([\w\/]+)$/,
                         $cgi->param()
        )
  );
}

my $new = new FS::svc_domain ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(svcnum pkgnum svcpart domain action)
  } ( fields('svc_domain'), qw( pkgnum svcpart action ) )
} );

my $error = '';
if ($cgi->param('svcnum')) {
  $error  = $new->replace();
} else {
  $error  = $new->insert;
  $svcnum = $new->svcnum;
}

</%init>
