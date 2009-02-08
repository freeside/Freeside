<% include( 'elements/browse.html',
                 'title'                 => 'Package Definitions',
                 'html_init'             => $html_init,
                 'name'                  => 'package definitions',
                 'disableable'           => 1,
                 'disabled_statuspos'    => 3,
                 'agent_virt'            => 1,
                 'agent_null_right'      => [ $edit, $edit_global ],
                 'agent_null_right_link' => $edit_global,
                 'agent_pos'             => 5,
                 'query'                 => { 'select'    => $select,
                                              'table'     => 'part_pkg',
                                              'hashref'   => {},
                                              'extra_sql' => $extra_sql,
                                              'order_by'  => "ORDER BY $orderby"
                                            },
                 'count_query'           => $count_query,
                 'header'                => \@header,
                 'fields'                => \@fields,
                 'links'                 => \@links,
                 'align'                 => $align,
             )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

my $edit        = 'Edit package definitions';
my $edit_global = 'Edit global package definitions';
my $acl_edit        = $curuser->access_right($edit);
my $acl_edit_global = $curuser->access_right($edit_global);
my $acl_config      = $curuser->access_right('Configuration'); #to edit services

die "access denied"
  unless $acl_edit || $acl_edit_global;

my $conf = new FS::Conf;
my $taxclasses = $conf->exists('enable_taxclasses');
my $money_char = $conf->config('money_char') || '$';

my $select = '*';
my $orderby = 'pkgpart';
if ( $cgi->param('active') ) {
  $orderby = 'num_active DESC';
}

my $extra_sql = '';

#false laziness w/elements/select-part_pkg.html
my $agentnums = join(',', $curuser->agentnums);

unless ( $acl_edit_global ) {
  $extra_sql .= "
    WHERE (
      agentnum IS NOT NULL OR 0 < (
        SELECT COUNT(*)
          FROM type_pkgs
            LEFT JOIN agent_type USING ( typenum )
            LEFT JOIN agent AS typeagent USING ( typenum )
          WHERE type_pkgs.pkgpart = part_pkg.pkgpart
            AND typeagent.agentnum IN ($agentnums)
      )
    )
  ";
}
#eofalse

my $count_cust_pkg = "
  SELECT COUNT(*) FROM cust_pkg LEFT JOIN cust_main USING ( custnum )
    WHERE cust_pkg.pkgpart = part_pkg.pkgpart
      AND cust_main.agentnum IN ($agentnums)
";

$select = "

  *,

  ( $count_cust_pkg
      AND ( cancel IS NULL OR cancel = 0 )
      AND ( susp IS NULL OR susp = 0 )
  ) AS num_active,

  ( $count_cust_pkg
      AND ( cancel IS NULL OR cancel = 0 )
      AND susp IS NOT NULL AND susp != 0
  ) AS num_suspended,

  ( $count_cust_pkg
      AND cancel IS NOT NULL AND cancel != 0
  ) AS num_cancelled

";

my $html_init;
#unless ( $cgi->param('active') ) {
  $html_init = qq!
    One or more service definitions are grouped together into a package 
    definition and given pricing information.  Customers purchase packages
    rather than purchase services directly.<BR><BR>
    <A HREF="${p}edit/part_pkg.cgi"><I>Add a new package definition</I></A>
    <BR><BR>
  !;
#}

# ------

my $link = [ $p.'edit/part_pkg.cgi?', 'pkgpart' ];

my @header = ( '#', 'Package', 'Comment' );
my @fields = ( 'pkgpart', 'pkg', 'comment' );
my $align = 'rll';
my @links = ( $link, $link, '' );

unless ( 0 ) { #already showing only one class or something?
  push @header, 'Class';
  push @fields, sub { shift->classname || '(none)'; };
  $align .= 'l';
}

tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };

tie my %plan_labels, 'Tie::IxHash',
  map {  $_ => ( $plans{$_}->{'shortname'} || $plans{$_}->{'name'} ) }
      keys %plans;

push @header, 'Pricing';
$align .= 'r'; #?
push @fields, sub {
  my $part_pkg = shift;
  (my $plan = $plan_labels{$part_pkg->plan} ) =~ s/ /&nbsp;/g;
  my $is_recur = ( $part_pkg->freq ne '0' );

  [
    [
      { data =>$plan,
        align=>'center',
        colspan=>2,
      },
    ],
    [
      { data =>$money_char.
               sprintf('%.2f', $part_pkg->option('setup_fee') ),
        align=>'right'
      },
      { data => ( $is_recur ? ' setup' : ' one-time' ),
        align=>'left',
      },
    ],
    [
      { data=>( $is_recur
                  ? $money_char.sprintf('%.2f ', $part_pkg->option('recur_fee') )
                  : $part_pkg->freq_pretty
              ),
        align=> ( $is_recur ? 'right' : 'center' ),
        colspan=> ( $is_recur ? 1 : 2 ),
      },
      ( $is_recur
        ?  { data => ( $is_recur ? $part_pkg->freq_pretty : '' ),
             align=>'left',
           }
        : ()
      ),
    ],
    ( map { 
            my $dst_pkg = $_->dst_pkg;
            [ 
              { data => 'Add-on:&nbsp;'.$dst_pkg->pkg_comment,
                align=>'center', #?
                colspan=>2,
              }
            ]
          }
      $part_pkg->bill_part_pkg_link
    ),
  ];

#  $plan_labels{$part_pkg->plan}.'<BR>'.
#    $money_char.sprintf('%.2f setup<BR>', $part_pkg->option('setup_fee') ).
#    ( $part_pkg->freq ne '0'
#      ? $money_char.sprintf('%.2f ', $part_pkg->option('recur_fee') )
#      : ''
#    ).
#    $part_pkg->freq_pretty; #.'<BR>'
};

#if ( $cgi->param('active') ) {
  push @header, 'Customer<BR>packages';
  my %col = (
    'active'          => '00CC00',
    'suspended'       => 'FF9900',
    'cancelled'       => 'FF0000',
    #'one-time charge' => '000000',
    'charge'          => '000000',
  );
  my $cust_pkg_link = $p. 'search/cust_pkg.cgi?pkgpart=';
  push @fields, sub { my $part_pkg = shift;
                      [
                        map {
                              my $magic = $_;
                              my $label = $_;
                              if ( $magic eq 'active' && $part_pkg->freq == 0 ) {
                                $magic = 'inactive';
                                #$label = 'one-time charge',
                                $label = 'charge',
                              }
                          
                              [
                                {
                                 'data'  => '<B><FONT COLOR="#'. $col{$label}. '">'.
                                            $part_pkg->get("num_$_").
                                            '</FONT></B>',
                                 'align' => 'right',
                                },
                                {
                                 'data'  => $label.
                                              ( $part_pkg->get("num_$_") != 1
                                                && $label =~ /charge$/
                                                  ? 's'
                                                  : ''
                                              ),
                                 'align' => 'left',
                                 'link'  => ( $part_pkg->get("num_$_")
                                                ? $cust_pkg_link.
                                                  $part_pkg->pkgpart.
                                                  ";magic=$magic"
                                                : ''
                                            ),
                                },
                              ],
                            } (qw( active suspended cancelled ))
                      ]; };
  $align .= 'r';
#}

if ( $taxclasses ) {
  push @header, 'Taxclass';
  push @fields, sub { shift->taxclass() || '&nbsp;'; };
  $align .= 'l';
}

push @header, 'Plan options',
              'Services';
              #'Service', 'Quan', 'Primary';

push @fields, 
              sub {
                    my $part_pkg = shift;
                    if ( $part_pkg->plan ) {

                      my %options = $part_pkg->options;

                      [ map { 
                              [
                                { 'data'  => $_,
                                  'align' => 'right',
                                },
                                { 'data'  => $part_pkg->format($_,$options{$_}),
                                  'align' => 'left',
                                },
                              ];
                            }
                        grep { $options{$_} =~ /\S/ } 
                        grep { $_ !~ /^(setup|recur)_fee$/ }
                        keys %options
                      ];

                    } else {

                      [ map { [
                                { 'data'  => uc($_),
                                  'align' => 'right',
                                },
                                {
                                  'data'  => $part_pkg->$_(),
                                  'align' => 'left',
                                },
                              ];
                            }
                        (qw(setup recur))
                      ];

                    }

                  },

              sub {
                    my $part_pkg = shift;

                    [ 
                      (map {
                             my $pkg_svc = $_;
                             my $part_svc = $pkg_svc->part_svc;
                             my $svc = $part_svc->svc;
                             if ( $pkg_svc->primary_svc =~ /^Y/i ) {
                               $svc = "<B>$svc (PRIMARY)</B>";
                             }
                             $svc =~ s/ +/&nbsp;/g;

                             [
                               {
                                 'data'  => '<B>'. $pkg_svc->quantity. '</B>',
                                 'align' => 'right'
                               },
                               {
                                 'data'  => $svc,
                                 'align' => 'left',
                                 'link'  => ( $acl_config
                                                ? $p. 'edit/part_svc.cgi?'.
                                                  $part_svc->svcpart
                                                : ''
                                            ),
                               },
                             ];
                           }
                      sort {     $b->primary_svc =~ /^Y/i
                             <=> $a->primary_svc =~ /^Y/i
                           }
                           $part_pkg->pkg_svc('disable_linked'=>1)
                      ),
                      ( map { 
                              my $dst_pkg = $_->dst_pkg;
                              [
                                { data => 'Add-on:&nbsp;'.$dst_pkg->pkg_comment,
                                  align=>'center', #?
                                  colspan=>2,
                                }
                              ]
                            }
                        $part_pkg->svc_part_pkg_link
                      )
                    ];

                  };

$align .= 'lrl'; #rr';

# --------

my $count_query = "SELECT COUNT(*) FROM part_pkg $extra_sql";

</%init>
