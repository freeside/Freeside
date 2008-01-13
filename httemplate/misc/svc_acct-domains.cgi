[ <% join(', ', map { qq("$_->[0]", "$_->[1]") } @svc_domain) %> ]
<%init>

my $conf = new FS::Conf;

my $pkgpart_svcpart = $cgi->param('arg');
$pkgpart_svcpart =~ /^\d+_(\d+)$/;
my $part_svc = qsearchs('part_svc', { 'svcpart' => $1 }) if $1;
my $part_svc_column = $part_svc->part_svc_column('domsvc') if $part_svc;

my @output = split /,/, $part_svc_column->columnvalue if $part_svc_column;
my $columnflag = $part_svc_column->columnflag if $part_svc_column;
my @svc_domain = ();
my %seen = ();

foreach (@output) {
  my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $_ })
    or warn "unknown svc_domain.svcnum $_ for part_svc_column domsvc; ".
       "svcpart = " . $part_svc->svcpart;
  push @svc_domain, [ $_ => $svc_domain->domain ];
  $seen{$_}++;
}
if ($conf->exists('svc_acct-alldomains')
     && ( $columnflag eq 'D' || $columnflag eq '' )
   ) {
  foreach (grep { $_->svcnum ne $output[0] } qsearch('svc_domain', {}) ){
    push @svc_domain, [ $_->svcnum => $_->domain ];
  }
}

</%init>
