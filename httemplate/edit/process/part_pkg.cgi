<% include( 'elements/process.html',
              #'debug'             => 1,
              'table'             => 'part_pkg',
              'redirect'          => $redirect_callback,
              'viewall_dir'       => 'browse',
              'viewall_ext'       => 'cgi',
              'edit_ext'          => 'cgi',
              #XXX usable with cloning? #'agent_null_right'  => 'Edit global package definitions',
              'precheck_callback' => $precheck_callback,
              'args_callback'     => $args_callback,
              'process_m2m'       => \@process_m2m,
          )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Edit package definitions')
      || $curuser->access_right('Edit global package definitions')
      || ( ! $cgi->param('pkgpart') && $cgi->param('pkgnum') && $curuser->access_right('Customize customer package') );

my $precheck_callback = sub {
  my( $cgi ) = @_;

  my $conf = new FS::Conf;

  foreach (qw( setuptax recurtax disabled )) {
    $cgi->param($_, '') unless defined $cgi->param($_);
  }

  return 'Must select a tax class'
    if $cgi->param('taxclass') eq '(select)';

  my @agents = ();
  foreach ($cgi->param('agent_type')) {
    /^(\d+)$/;
    push @agents, $1 if $1;
  }
  return "At least one agent type must be specified."
    unless( scalar(@agents) ||
            $cgi->param('clone') && $cgi->param('clone') =~ /^\d+$/ ||
            !$cgi->param('pkgpart') && $conf->exists('agent-defaultpkg')
          );

  return '';

};

my $custnum = '';

my $args_callback = sub {
  my( $cgi, $new ) = @_;
  
  my @args = ( 'primary_svc' => scalar($cgi->param('pkg_svc_primary')) );

  ##
  #options
  ##
  
  $cgi->param('plan') =~ /^(\w+)$/ or die 'unparsable plan';
  my $plan = $1;
  
  tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };
  my $href = $plans{$plan}->{'fields'};
  
  my $error = '';
  my $options = $cgi->param($plan."__OPTIONS");
  my @options = split(',', $options);
  my %options =
    map { my $optionname = $_;
          my $param = $plan."__$optionname";
          my $parser = exists($href->{$optionname}{parse})
                         ? $href->{$optionname}{parse}
                         : sub { shift };
          my $value = join(', ', &$parser($cgi->param($param)));
          my $check = $href->{$optionname}{check};
          if ( $check && ! &$check($value) ) {
            $value = join(', ', $cgi->param($param));
            $error ||= "Illegal ".
                         ($href->{$optionname}{name}||$optionname). ": $value";
          }
          ( $optionname => $value );
        }
        @options;

  $options{$_} = scalar( $cgi->param($_) )
    for (qw( setup_fee recur_fee ));
  
  push @args, 'options' => \%options;

  ###
  #pkg_svc
  ###

  my %pkg_svc = map { $_ => scalar($cgi->param("pkg_svc$_")) }
                map { $_->svcpart }
                qsearch('part_svc', {} );

  push @args, 'pkg_svc' => \%pkg_svc;

  ###
  # cust_pkg and custnum_ref (inserts only)
  ###
  unless ( $cgi->param('pkgpart') ) {
    push @args, 'cust_pkg'    => scalar($cgi->param('pkgnum')),
                'custnum_ref' => \$custnum;
  }

  warn "args: ".join('/', @args). "\n";

  @args;

};

my $redirect_callback = sub {
  #my( $cgi, $new ) = @_;
  return '' unless $custnum;
  popurl(3). "view/cust_main.cgi?keywords=$custnum;dummy=";
};

#these should probably move to @args above and be processed by part_pkg.pm...

$cgi->param('tax_override') =~ /^([\d,]+)$/;
my (@tax_overrides) = (grep "$_", split (",", $1));

my @process_m2m = (
  {
    'link_table'   => 'part_pkg_taxoverride',
    'target_table' => 'tax_class',
    'params'       => \@tax_overrides,
  },
  { 'link_table'   => 'part_pkg_link',
    'target_table' => 'part_pkg',
    'base_field'   => 'src_pkgpart',
    'target_field' => 'dst_pkgpart',
    'hashref'      => { 'link_type' => 'bill' },
    'params'       => [ map $cgi->param($_), grep /^bill_dst_pkgpart/, $cgi->param ],
  },
  { 'link_table'   => 'part_pkg_link',
    'target_table' => 'part_pkg',
    'base_field'   => 'src_pkgpart',
    'target_field' => 'dst_pkgpart',
    'hashref'      => { 'link_type' => 'svc' },
    'params'       => [ map $cgi->param($_), grep /^svc_dst_pkgpart/, $cgi->param ],
  },
);

my $conf = new FS::Conf;

if ( $cgi->param('pkgpart') || ! $conf->exists('agent_defaultpkg') ) {
  my @agents = ();
  foreach ($cgi->param('agent_type')) {
    /^(\d+)$/;
    push @agents, $1 if $1;
  }
  push @process_m2m, {
    'link_table'   => 'type_pkgs',
    'target_table' => 'agent_type',
    'params'       => \@agents,
  };
}

</%init>
