%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "svc_acct.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_acct.cgi?" . $svcnum ) %>
%}
<%init>
use CGI::Carp;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $old;
if ( $svcnum ) {
  $old = qsearchs('svc_acct', { 'svcnum' => $svcnum } )
    or die "fatal: can't find account (svcnum $svcnum)!";
} else {
  $old = '';
}

#unmunge popnum
$cgi->param('popnum', (split(/:/, $cgi->param('popnum') ))[0] );

#unmunge usergroup
$cgi->param('usergroup', [ $cgi->param('radius_usergroup') ] );

#unmunge bytecounts
foreach (map { $_,$_."_threshold" } qw( upbytes downbytes totalbytes )) {
  $cgi->param($_, FS::UI::bytecount::parse_bytecount($cgi->param($_)) );
}

#unmunge cgp_accessmodes (falze laziness-ish w/part_svc.pm::process &svc_domain)
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

my %hash = $svcnum ? $old->hash : ();
map {
    $hash{$_} = scalar($cgi->param($_));
  #} qw(svcnum pkgnum svcpart username _password popnum uid gid finger dir
  #  shell quota slipip)
  } (fields('svc_acct'), qw ( pkgnum svcpart usergroup ));
my $new = new FS::svc_acct ( \%hash );

my $error = '';

$new->_password($old->_password) if $old;
if (     $cgi->param('clear_password') eq '*HIDDEN*'
      || $cgi->param('clear_password') =~ /^\(.* encrypted\)$/ ) {
  die "fatal: no previous account to recall hidden password from!" unless $old;
} else {
  $error = $new->set_password($cgi->param('clear_password'));
}

if ( $svcnum ) {
  foreach ( grep { $old->$_ != $new->$_ }
                 qw( seconds upbytes downbytes totalbytes )
          )
  {
    my %hash = map { $_ => $new->$_ } 
               grep { $new->$_ }
               qw( seconds upbytes downbytes totalbytes );

    $error ||= $new->set_usage(\%hash);  #unoverlimit and trigger radius changes
    last;                                #once is enough
  }
  $error ||= $new->replace($old);
} else {
  $error ||= $new->insert;
  $svcnum = $new->svcnum;
}

</%init>
