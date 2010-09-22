<% include( 'elements/process.html',
              #'debug'             => 1,
              'table'             => 'part_pkg',
              'agent_virt'        => 1,
              'agent_null_right'  => \@agent_null_right,
              'redirect'          => $redirect_callback,
              'viewall_dir'       => 'browse',
              'viewall_ext'       => 'cgi',
              'edit_ext'          => 'cgi',
              'precheck_callback' => $precheck_callback,
              'args_callback'     => $args_callback,
              'process_m2m'       => \@process_m2m,
          )
%>
<%init>

my $customizing = ( ! $cgi->param('pkgpart') && $cgi->param('pkgnum') );

my $curuser = $FS::CurrentUser::CurrentUser;

my $edit_global = 'Edit global package definitions';
my $customize   = 'Customize customer package';

die "access denied"
  unless $curuser->access_right('Edit package definitions')
      || $curuser->access_right($edit_global)
      || ( $customizing && $curuser->access_right($customize) );

my @agent_null_right = ( $edit_global );
push @agent_null_right, $customize if $customizing;


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
    unless scalar(@agents)
           || ( $cgi->param('clone') && $cgi->param('clone') =~ /^\d+$/ )
           || ( !$cgi->param('pkgpart') && $conf->exists('agent-defaultpkg') )
           || $cgi->param('disabled')
           || $cgi->param('agentnum');

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
        grep { $_ !~ /^report_option_/ }
        @options;

  foreach ( split(',', $cgi->param('taxproductnums') ) ) {
    my $value = $cgi->param("taxproductnum_$_");
    $error ||= "Illegal taxproductnum_$_: $value"
      unless ( $value =~ /^\d*$/  );
    $options{"usage_taxproductnum_$_"} = $value;
  }

  foreach ( $cgi->param('report_option') ) {
    $error ||= "Illegal optional report class: $_" unless ( $_ =~ /^\d*$/  );
    $options{"report_option_$_"} = 1;
  }

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

  #warn "args: ".join('/', @args). "\n";

  @args;

};

my $redirect_callback = sub {
  #my( $cgi, $new ) = @_;
  return '' unless $custnum;
  my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
               ? ''
               : ';show=packages';
  #my $frag = "cust_pkg$pkgnum"; #hack for IE ignoring real #fragment
 
  #can we link back to the specific customized package?  it would be nice...
  popurl(3). "view/cust_main.cgi?custnum=$custnum$show;dummy=";
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
  { 'link_table'   => 'part_pkg_discount',
    'target_table' => 'discount',
    'params'       => [ map $cgi->param($_),
                        grep /^discountnum/, $cgi->param
                      ],
  },
  { 'link_table'   => 'part_pkg_link',
    'target_table' => 'part_pkg',
    'base_field'   => 'src_pkgpart',
    'target_field' => 'dst_pkgpart',
    'hashref'      => { 'link_type' => 'svc', 'hidden' => '' },
    'params'       => [ map $cgi->param($_),
                        grep /^svc_dst_pkgpart/, $cgi->param
                      ],
  },
  map { 
    my $hidden = $_;
    { 'link_table'   => 'part_pkg_link',
      'target_table' => 'part_pkg',
      'base_field'   => 'src_pkgpart',
      'target_field' => 'dst_pkgpart',
      'hashref'      => { 'link_type' => 'bill', 'hidden' => $hidden },
      'params'       => [ map { $cgi->param($_) }
                          grep { my $param = "bill_dst_pkgpart__hidden";
                                 my $digit = '';
                                 (($digit) = /^bill_dst_pkgpart(\d+)/ ) &&
                                 $cgi->param("$param$digit") eq $hidden;
                               }
                          $cgi->param
                        ],
    },
  } ( '', 'Y' ),
);

foreach my $override_class ($cgi->param) {
  next unless $override_class =~ /^tax_override_(\w+)$/;
  my $class = $1;

  my (@tax_overrides) = (grep "$_", split (",", $1))
    if $cgi->param($override_class) =~ /^([\d,]+)$/;

  push @process_m2m, {
    'link_table'   => 'part_pkg_taxoverride',
    'target_table' => 'tax_class',
    'hashref'      => { 'usage_class' => $class },
    'params'       => [ @tax_overrides ],
  };

}

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
