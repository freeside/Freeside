<% include( 'elements/browse.html',
                 'title'                 => 'Package Definitions',
                 'html_init'             => $html_init,
                 'html_posttotal'        => $html_posttotal,
                 'name'                  => 'package definitions',
                 'disableable'           => 1,
                 'disabled_statuspos'    => 4,
                 'agent_virt'            => 1,
                 'agent_null_right'      => [ $edit, $edit_global ],
                 'agent_null_right_link' => $edit_global,
                 'agent_pos'             => 6,
                 'query'                 => { 'select'    => $select,
                                              'table'     => 'part_pkg',
                                              'hashref'   => \%hash,
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
                                                               #and agent types
                                                               #and bulk change

die "access denied"
  unless $acl_edit || $acl_edit_global;

my $conf = new FS::Conf;
my $taxclasses = $conf->exists('enable_taxclasses');
my $money_char = $conf->config('money_char') || '$';

my $select = '*';
my $orderby = 'pkgpart';
my %hash = ();
my $extra_count = '';
my $family_pkgpart;

if ( $cgi->param('active') ) {
  $orderby = 'num_active DESC';
}

my @where = ();

#if ( $cgi->param('activeONLY') ) {
#  push @where, ' WHERE num_active > 0 '; #XXX doesn't affect count...
#}

if ( $cgi->param('recurring') ) {
  $hash{'freq'} = { op=>'!=', value=>'0' };
  $extra_count = " freq != '0' ";
}

my $classnum = '';
if ( $cgi->param('classnum') =~ /^(\d+)$/ ) {
  $classnum = $1;
  push @where, $classnum ? "classnum =  $classnum"
                         : "classnum IS NULL";
}
$cgi->delete('classnum');

if ( $cgi->param('missing_recur_fee') ) {
  push @where, "0 = ( SELECT COUNT(*) FROM part_pkg_option
                        WHERE optionname = 'recur_fee'
                          AND part_pkg_option.pkgpart = part_pkg.pkgpart
                          AND CAST( optionvalue AS NUMERIC ) > 0
                    )";
}

if ( $cgi->param('family') =~ /^(\d+)$/ ) {
  $family_pkgpart = $1;
  push @where, "family_pkgpart = $1";
  # Hiding disabled or one-time charges and limiting by classnum aren't 
  # very useful in this mode, so all links should still refer back to the 
  # non-family-limited display.
  $cgi->param('showdisabled', 1);
  $cgi->delete('family');
}

push @where, FS::part_pkg->curuser_pkgs_sql
  unless $acl_edit_global;

my $extra_sql = scalar(@where)
                ? ( scalar(keys %hash) ? ' AND ' : ' WHERE ' ).
                  join( 'AND ', @where)
                : '';

my $agentnums_sql = $curuser->agentnums_sql( 'table'=>'cust_main' );
my $count_cust_pkg = "
  SELECT COUNT(*) FROM cust_pkg LEFT JOIN cust_main USING ( custnum )
    WHERE cust_pkg.pkgpart = part_pkg.pkgpart
      AND $agentnums_sql
";

$select = "

  *,

  ( $count_cust_pkg
      AND ( setup IS NULL OR setup = 0 )
      AND ( cancel IS NULL OR cancel = 0 )
      AND ( susp IS NULL OR susp = 0 )
  ) AS num_not_yet_billed,

  ( $count_cust_pkg
      AND setup IS NOT NULL AND setup != 0
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
    <FORM METHOD="POST" ACTION="${p}edit/part_pkg.cgi">
    <A HREF="${p}edit/part_pkg.cgi"><I>Add a new package definition</I></A>
    or
    !.include('/elements/select-part_pkg.html', 'element_name' => 'clone' ). qq!
    <INPUT TYPE="submit" VALUE="Clone existing package">
    </FORM>
    <BR><BR>
  !;
#}

$cgi->param('dummy', 1);

my $filter_change =
  qq(\n<SCRIPT TYPE="text/javascript">\n).
  "function filter_change() {".
  "  window.location = '". $cgi->self_url.
       ";classnum=' + document.getElementById('classnum').options[document.getElementById('classnum').selectedIndex].value".
  "}".
  "\n</SCRIPT>\n";

#restore this so pagination works
$cgi->param('classnum', $classnum) if length($classnum);

#should hide this if there aren't any classes
my $html_posttotal =
  "$filter_change\n<BR>( show class: ".
  include('/elements/select-pkg_class.html',
            #'curr_value'    => $classnum,
            'value'         => $classnum, #insist on 0 :/
            'onchange'      => 'filter_change()',
            'pre_options'   => [ '-1' => 'all',
                                 '0'  => '(none)', ],
            'disable_empty' => 1,
         ).
  ' )';

my $recur_toggle = $cgi->param('recurring') ? 'show' : 'hide';
$cgi->param('recurring', $cgi->param('recurring') ^ 1 );

$html_posttotal .=
  '( <A HREF="'. $cgi->self_url.'">'. "$recur_toggle one-time charges</A> )";

$cgi->param('recurring', $cgi->param('recurring') ^ 1 ); #put it back

# ------

my $link = [ $p.'edit/part_pkg.cgi?', 'pkgpart' ];

my @header = ( '#', 'Package', 'Comment', 'Custom' );
my @fields = ( 'pkgpart', 'pkg', 'comment',
               sub{ '<B><FONT COLOR="#0000CC">'.$_[0]->custom.'</FONT></B>' }
             );
my $align = 'rllc';
my @links = ( $link, $link, '', '' );

unless ( 0 ) { #already showing only one class or something?
  push @header, 'Class';
  push @fields, sub { shift->classname || '(none)'; };
  $align .= 'l';
}

if ( $conf->exists('pkg-addon_classnum') ) {
  push @header, "Add'l order class";
  push @fields, sub { shift->addon_classname || '(none)'; };
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
  my @discounts = sort { $a->months <=> $b->months }
                  map { $_->discount  }
                  $part_pkg->part_pkg_discount;

  [
    ( !$family_pkgpart &&
      $part_pkg->pkgpart == $part_pkg->family_pkgpart ? () : [
      {
        'align'=> 'center',
        'colspan' => 2,
        'size' => '-1',
        'data' => '<b>Show all versions</b>',
        'link' => $p.'browse/part_pkg.cgi?family='.$part_pkg->family_pkgpart,
      }
    ] ),
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
      { data => ( ( $is_recur ? ' setup' : ' one-time' ).
                  ( $part_pkg->option('recur_fee') == 0
                      && $part_pkg->setup_show_zero
                    ? ' (printed on invoices)'
                    : ''
                  )
                ),
        align=>'left',
      },
    ],
    [
      { data=>(
          $is_recur
            ? $money_char. sprintf('%.2f ', $part_pkg->option('recur_fee'))
            : $part_pkg->freq_pretty
        ),
        align=> ( $is_recur ? 'right' : 'center' ),
        colspan=> ( $is_recur ? 1 : 2 ),
      },
      ( $is_recur
        ?  { data => ( $is_recur
               ? $part_pkg->freq_pretty.
                 ( $part_pkg->option('recur_fee') == 0
                     && $part_pkg->recur_show_zero
                   ? ' (printed on invoices)'
                   : ''
                 )
               : '' ),
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
    ( scalar(@discounts)
        ?  [ 
              { data => '<b>Discounts</b>',
                align=>'center', #?
                colspan=>2,
              }
            ]
        : ()  
    ),
    ( scalar(@discounts)
        ? map { 
            [ 
              { data  => $_->months. ':',
                align => 'right',
              },
              { data => $_->amount ? '$'. $_->amount : $_->percent. '%'
              }
            ]
          }
          @discounts
        : ()
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

###
# Agent goes here if displayed
###

#agent type
if ( $acl_edit_global ) {
  #really we just want a count, but this is fine unless someone has tons
  my @all_agent_types = map {$_->typenum} qsearch('agent_type',{});
  if ( scalar(@all_agent_types) > 1 ) {
    push @header, 'Agent types';
    my $typelink = $p. 'edit/agent_type.cgi?';
    push @fields, sub { my $part_pkg = shift;
                        [
                          map { my $agent_type = $_->agent_type;
                                [ 
                                  { 'data'  => $agent_type->atype, #escape?
                                    'align' => 'left',
                                    'link'  => ( $acl_config
                                                   ? $typelink.
                                                     $agent_type->typenum
                                                   : ''
                                               ),
                                  },
                                ];
                              }
                              $part_pkg->type_pkgs
                        ];
                      };
    $align .= 'l';
  }
}

#if ( $cgi->param('active') ) {
  push @header, 'Customer<BR>packages';
  my %col = (
    'not yet billed'  => '009999', #teal? cyan?
    'active'          => '00CC00',
    'suspended'       => 'FF9900',
    'cancelled'       => 'FF0000',
    #'one-time charge' => '000000',
    'charge'          => '000000',
  );
  my $cust_pkg_link = $p. 'search/cust_pkg.cgi?pkgpart=';
  push @fields, sub { my $part_pkg = shift;
                        [
                        map( {
                              my $magic = $_;
                              my $label = $_;
                              if ( $magic eq 'active' && $part_pkg->freq == 0 ) {
                                $magic = 'inactive';
                                #$label = 'one-time charge',
                                $label = 'charge',
                              }
                              $label= 'not yet billed' if $magic eq 'not_yet_billed';
                          
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
                            } (qw( not_yet_billed active suspended cancelled ))
                          ),
                      ($acl_config ? 
                        [ {}, 
                          { 'data'  => '<FONT SIZE="-1">[ '.
                              include('/elements/popup_link.html',
                                'label'       => 'change',
                                'action'      => "${p}edit/bulk-cust_pkg.html?".
                                                 'pkgpart='.$part_pkg->pkgpart,
                                'actionlabel' => 'Change Packages',
                                'width'       => 569,
                                'height'      => 210,
                              ).' ]</FONT>',
                            'align' => 'left',
                          } 
                        ] : () ),
                      ]; 
  };
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
                                { 'data'  => "$_: ",
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

my $count_extra_sql = $extra_sql;
$count_extra_sql =~ s/^\s*AND /WHERE /i;
$extra_count = ( $count_extra_sql ? ' AND ' : ' WHERE ' ). $extra_count
  if $extra_count;
my $count_query = "SELECT COUNT(*) FROM part_pkg $count_extra_sql $extra_count";

</%init>
