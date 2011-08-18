<& elements/search.html,
                  'html_init'   => $html_init, 
                  'title'       => emt('Package Search Results'), 
                  'name'        => 'packages',
                  'query'       => $sql_query,
                  'count_query' => $count_query,
                  'header'      => [ emt('#'),
                                     emt('Quan.'),
                                     emt('Package'),
                                     emt('Class'),
                                     emt('Status'),
                                     emt('Setup'),
                                     emt('Base Recur'),
                                     emt('Freq.'),
                                     emt('Setup'),
                                     emt('Last bill'),
                                     emt('Next bill'),
                                     emt('Adjourn'),
                                     emt('Susp.'),
                                     emt('Susp. delay'),
                                     emt('Expire'),
                                     emt('Contract end'),
                                     emt('Cancel'),
                                     emt('Reason'),
                                     FS::UI::Web::cust_header(
                                       $cgi->param('cust_fields')
                                     ),
                                     emt('Services'),
                                   ],
                  'fields'      => [
                    'pkgnum',
                    'quantity',
                    sub { $_[0]->pkg; },
                    'classname',
                    sub { ucfirst(shift->status); },
                    sub { sprintf( $money_char.'%.2f',
                                   shift->part_pkg->option('setup_fee'),
                                 );
                        },
                    sub { my $c = shift;
                          sprintf( $money_char.'%.2f',
                                   $c->part_pkg->base_recur($c)
                                 );
                        },
                    sub { FS::part_pkg::freq_pretty(shift); },

                    ( map { time_or_blank($_) }
          qw( setup last_bill bill adjourn susp dundate expire contract_end cancel ) ),

                    sub { my $self = shift;
                          my $return = '';
                          foreach my $action ( qw ( cancel susp ) ) {
                            my $reason = $self->last_reason($action);
                            $return = $reason->reason if $reason;
                            last if $return;
                          }
                          $return;
                        },

                    \&FS::UI::Web::cust_fields,
                    sub {
                      my $cust_pkg = shift;
                      my $type = $cgi->param('_type') || '';
                      if ($type =~ /xls|csv/) {
                        my $cust_svc = $cust_pkg->primary_cust_svc;
                        if($cust_svc) {
                          return join ": ",($cust_svc->label)[0,1];
                        }
                        else {
                          return '';
                        }
                      }
                      else {
                          [ $process_svc_labels->( $cust_pkg ) ]
                      }
                    }
                  ],
                  'color' => [
                    '',
                    '',
                    '',
                    '',
                    sub { shift->statuscolor; },
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    FS::UI::Web::cust_colors(),
                    '',
                  ],
                  'style' => [ '', '', '', '', 'b', '', '', '', '', '', '', '', '', '', '', '', '', '',
                               FS::UI::Web::cust_styles() ],
                  'size'  => [ '', '', '', '', '-1' ],
                  'align' => 'rrlccrrlrrrrrrrrrl'. FS::UI::Web::cust_aligns(). 'r',
                  'links' => [
                    $link,
                    $link,
                    $link,
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    ( map { $_ ne 'Cust. Status' ? $clink : '' }
                          FS::UI::Web::cust_header(
                                                    $cgi->param('cust_fields')
                                                  )
                    ),
                    '',
                  ],
&>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('List packages');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my %search_hash = ();

#some false laziness w/misc/bulk_change_pkg.cgi
  
$search_hash{'query'} = $cgi->keywords;

#scalars
for (qw( agentnum custnum magic status custom cust_fields pkgbatch )) {
  $search_hash{$_} = $cgi->param($_) if $cgi->param($_);
}

#arrays
for my $param (qw( pkgpart classnum )) {
  $search_hash{$param} = [ $cgi->param($param) ]
    if grep { $_ eq $param } $cgi->param;
}

#scalars that need to be passed if empty
for my $param (qw( censustract censustract2 )) {
  $search_hash{$param} = $cgi->param($param) || ''
    if grep { $_ eq $param } $cgi->param;
}

my $report_option = $cgi->param('report_option');
$search_hash{report_option} = $report_option if $report_option;

for my $param (grep /^report_option_any/, $cgi->params) {
  $search_hash{$param} = $cgi->param($param);
}

###
# parse dates
###

#false laziness w/report_cust_pkg.html
my %disable = (
  'all'             => {},
  'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'adjourn'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, 'contract_end'=>1, 'dundate'=>1, },
  'active'          => { 'susp'=>1, 'cancel'=>1 },
  'suspended'       => { 'cancel' =>1, 'dundate'=>1, },
  'cancelled'       => {},
  ''                => {},
);

foreach my $field (qw( setup last_bill bill adjourn susp expire contract_end cancel active )) {

  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi, $field);

  next if $beginning == 0 && $ending == 4294967295
       or $disable{$cgi->param('status')}->{$field};

  $search_hash{$field} = [ $beginning, $ending ];

}

my $sql_query = FS::cust_pkg->search(\%search_hash);
my $count_query = delete($sql_query->{'count_query'});

my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
             ? ''
             : ';show=packages';

my $link = sub {
  my $self = shift;
  my $frag = 'cust_pkg'. $self->pkgnum; #hack for IE ignoring real #fragment
  [ "${p}view/cust_main.cgi?custnum=".$self->custnum.
                           "$show;fragment=$frag#cust_pkg",
    'pkgnum'
  ];
};

my $clink = sub {
  my $cust_pkg = shift;
  $cust_pkg->cust_main_custnum
    ? [ "${p}view/cust_main.cgi?", 'custnum' ] 
    : '';
};

sub time_or_blank {
   my $column = shift;
   return sub {
     my $record = shift;
     my $value = $record->get($column); #mmm closures
     $value ? time2str('%b %d %Y', $value ) : '';
   };
}

my $html_init = sub {
  my $query = shift;
  my $text = '';
  my $curuser = $FS::CurrentUser::CurrentUser;

  if ( $curuser->access_right('Bulk change customer packages') ) {
    $text .= include('/elements/init_overlib.html').
             include( '/elements/popup_link.html',
               'label'       => emt('Change these packages'),
               'action'      => "${p}misc/bulk_change_pkg.cgi?$query",
               'actionlabel' => emt('Change Packages'),
               'width'       => 569,
               'height'      => 210,
             ). '<BR>';

    if ( $curuser->access_right('Edit customer package dates') ) {
      $text .= include( '/elements/popup_link.html',
                 'label'       => emt('Increment next bill date'),
                 'action'      => "${p}misc/bulk_pkg_increment_bill.cgi?$query",
                 'actionlabel' => emt('Increment Bill Date'),
                 'width'       => 569,
                 'height'      => 210,
              ). '<BR>';
    }
    $text .= include( '/elements/email-link.html',
                'search_hash' => \%search_hash,
                'table'       => 'cust_pkg',
                ). '<BR><BR>';
  }
  return $text;
};

my $large_pkg_size = $conf->config('cust_pkg-large_pkg_size');

my $process_svc_labels = sub {
  my $cust_pkg = shift;
  my @out;
  foreach my $part_svc ( $cust_pkg->part_svc) {
    # some false laziness with view/cust_main/packages/services.html

    my $num_cust_svc = $cust_pkg->num_cust_svc( $part_svc->svcpart );

    if ( $large_pkg_size > 0 and $large_pkg_size <= $num_cust_svc ) {
      my $href = $p.'search/cust_pkg_svc.html?svcpart='.$part_svc->svcpart.
          ';pkgnum='.$cust_pkg->pkgnum;
      push @out, [
        { 'data'  => $part_svc->svc . ':',
          'align' => 'right',
          'rowspan' => 2 },
        { 'data'  => mt('(view all [_1])', $num_cust_svc),
          'data_style' => 'b',
          'align' => 'left',
          'link'  => $href, },
      ],
      [
        { 'data'  => include('/elements/search-cust_svc.html',
                        'svcpart' => $part_svc->svcpart,
                        'pkgnum'  => $cust_pkg->pkgnum,
                    ),
          'align' => 'left' },
      ];
    }
    else {
      foreach ( map { [ $_->label ] } @{ $part_svc->cust_pkg_svc } ) {
        push @out, [ 
        { 'data' => $_->[0]. ':',
          'align'=> 'right', },
        { 'data' => $_->[1],
          'align'=> 'left',
          'link' => $p. 'view/' .
          $_->[2]. '.cgi?'. $_->[3], },
        ];
      }
    }
  } #foreach $cust_pkg
  return @out;
};

</%init>
