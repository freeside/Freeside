%if ( $error ) {
%  $dbh->rollback if $oldAutoCommit;
%  $cgi->param('error', $error );
<% $cgi->redirect(popurl(2). "part_pkg.cgi?". $cgi->query_string ) %>
%} elsif ( $custnum )  {
%  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum") %>
%} else {
%  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
<% $cgi->redirect(popurl(3). "browse/part_pkg.cgi") %>
%}
<%init>

#1.7
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
#1.9
#die "access denied"
#  unless $FS::CurrentUser::CurrentUser->access_right('Edit package definitions')
#      || $FS::CurrentUser::CurrentUser->access_right('Edit global package definitions');

my $dbh = dbh;
my $conf = new FS::Conf;

my $pkgpart = $cgi->param('pkgpart');

my $old = qsearchs('part_pkg',{'pkgpart'=>$pkgpart}) if $pkgpart;

tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };
my $href = $plans{$cgi->param('plan')}->{'fields'};

#fixup plandata
my $error;
my $plandata = $cgi->param('plandata');
my @plandata = split(',', $plandata);
$cgi->param('plandata', 
  join('', map { my $parser = sub { shift };
                 $parser = $href->{$_}{parse} if exists($href->{$_}{parse});
                 my $value = join(', ', &$parser($cgi->param($_)));
                 my $check = $href->{$_}{check};
                 if ( $check && ! &$check($value) ) {
                   $value = join(', ', $cgi->param($_));
                   $error ||= "Illegal ". ($href->{$_}{name}||$_). ": $value";
                 }
                 "$_=$value\n";
               } @plandata )
);

foreach (qw( setuptax recurtax disabled )) {
  $cgi->param($_, '') unless defined $cgi->param($_);
}

my @agents;
foreach ($cgi->param('agent_type')) {
  /^(\d+)$/;
  push @agents, $1 if $1;
}
$error = "At least one agent type must be specified."
  unless( scalar(@agents) ||
          $cgi->param('clone') && $cgi->param('clone') =~ /^\d+$/ ||
          !$pkgpart && $conf->exists('agent-defaultpkg')
        );

my $new = new FS::part_pkg ( {
  map {
    $_ => scalar($cgi->param($_));
  } fields('part_pkg')
} );

my $oldAutoCommit = $FS::UID::AutoCommit;
local $FS::UID::AutoCommit = 0;

my %pkg_svc = map { $_ => scalar($cgi->param("pkg_svc$_")) }
              map { $_->svcpart }
              qsearch('part_svc', {} );

my $custnum = '';
if ( $error ) {

 # fall through

} elsif ( $cgi->param('taxclass') eq '(select)' ) {

  $error = 'Must select a tax class';

} elsif ( $pkgpart ) {

  $error = $new->replace( $old,
                          pkg_svc     => \%pkg_svc,
                          primary_svc => scalar($cgi->param('pkg_svc_primary')),
                        );
} else {

  $error = $new->insert(  pkg_svc     => \%pkg_svc,
                          primary_svc => scalar($cgi->param('pkg_svc_primary')),
                          cust_pkg    => $cgi->param('pkgnum'),
                          custnum_ref => \$custnum,
                       );
  $pkgpart = $new->pkgpart;
}

unless ( $error || $conf->exists('agent_defaultpkg') ) {
  my $error = $new->process_m2m(
    'link_table'   => 'type_pkgs',
    'target_table' => 'agent_type',
    'params'       => \@agents,
  );
}

</%init>

