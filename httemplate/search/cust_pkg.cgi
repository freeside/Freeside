<%

my %part_pkg = map { $_->pkgpart => $_ } qsearch('part_pkg', {});

my($query) = $cgi->keywords;

my $orderby;
my @where;
my $cjoin = '';

if ( $cgi->param('agentnum') =~ /^(\d+)$/ and $1 ) {
  $cjoin = "LEFT JOIN cust_main USING ( custnum )";
  push @where,
    "agentnum = $1";
}

if ( $cgi->param('magic') && $cgi->param('magic') eq 'bill' ) {
  $orderby = 'ORDER BY bill';

  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
  push @where,
    "bill >= $beginning ",
    "bill <= $ending",
    '( cancel IS NULL OR cancel = 0 )';

} else {

  if ( $cgi->param('magic') &&
       $cgi->param('magic') =~ /^(active|suspended|cancell?ed)$/
  ) {

    $orderby = 'ORDER BY pkgnum';

    if ( $cgi->param('magic') eq 'active' ) {

      #push @where,
      #  '( susp IS NULL OR susp = 0 )',
      #  '( cancel IS NULL OR cancel = 0)';
      push @where, FS::cust_pkg->active_sql();

    } elsif ( $cgi->param('magic') eq 'suspended' ) {

      push @where,
        'susp IS NOT NULL',
        'susp != 0',
        '( cancel IS NULL OR cancel = 0)';

    } elsif ( $cgi->param('magic') =~ /^cancell?ed$/ ) {

      push @where,
        'cancel IS NOT NULL',
        'cancel != 0';

    } else {
      die "guru meditation #420";
    }

    if ( $cgi->param('pkgpart') =~ /^(\d+)$/ ) {
      push @where, "pkgpart = $1";
    }

  } elsif ( $query eq 'pkgnum' ) {

    $orderby = 'ORDER BY pkgnum';

  } elsif ( $query eq 'APKG_pkgnum' ) {
  
    $orderby = 'ORDER BY pkgnum';
  
    push @where, '0 < (
      SELECT count(*) FROM pkg_svc
       WHERE pkg_svc.pkgpart =  cust_pkg.pkgpart
         AND pkg_svc.quantity > ( SELECT count(*) FROM cust_svc
                                   WHERE cust_svc.pkgnum  = cust_pkg.pkgnum
                                     AND cust_svc.svcpart = pkg_svc.svcpart
                                )
    )';
    
  } else {
    die "Empty or unknown QUERY_STRING!";
  }

}

my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

my $count_query = "SELECT COUNT(*) FROM cust_pkg $cjoin $extra_sql";

my $sql_query = {
  'table'     => 'cust_pkg',
  'hashref'   => {},
  'select'    => join(', ',
                            'cust_pkg.*',
                            'cust_main.custnum as cust_main_custnum',
                            FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => "$extra_sql $orderby",
  'addl_from' => ' LEFT JOIN cust_main USING ( custnum ) ',
                 #' LEFT JOIN part_pkg  USING ( pkgpart ) '
};

my $link = sub {
  [ "${p}view/cust_main.cgi?".shift->custnum.'#cust_pkg', 'pkgnum' ];
};

my $clink = sub {
  my $cust_pkg = shift;
  $cust_pkg->cust_main_custnum
    ? [ "${p}view/cust_main.cgi?", 'custnum' ] 
    : '';
};

#if ( scalar(@cust_pkg) == 1 ) {
#  print $cgi->redirect("${p}view/cust_main.cgi?". $cust_pkg[0]->custnum.
#                       "#cust_pkg". $cust_pkg[0]->pkgnum );

#    my @cust_svc = qsearch( 'cust_svc', { 'pkgnum' => $pkgnum } );
#    my $rowspan = scalar(@cust_svc) || 1;

#    my $n2 = '';
#    foreach my $cust_svc ( @cust_svc ) {
#      my($label, $value, $svcdb) = $cust_svc->label;
#      my $svcnum = $cust_svc->svcnum;
#      my $sview = $p. "view";
#      print $n2,qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$label</FONT></A></TD>!,
#            qq!<TD><A HREF="$sview/$svcdb.cgi?$svcnum"><FONT SIZE=-1>$value</FONT></A></TD>!;
#      $n2="</TR><TR>";
#    }

sub time_or_blank {
   my $column = shift;
   return sub {
     my $record = shift;
     my $value = $record->get($column); #mmm closures
     $value ? time2str('%b %d %Y', $value ) : '';
   };
}

%><%=  include( 'elements/search.html',
                  'title'       => 'Package Search Results', 
                  'name'        => 'packages',
                  'query'       => $sql_query,
                  'count_query' => $count_query,
                  'redirect'    => $link,
                  'header'      => [ '#',
                                     'Package',
                                     'Status',
                                     'Freq.',
                                     'Setup',
                                     'Last bill',
                                     'Next bill',
                                     'Susp.',
                                     'Expire',
                                     'Cancel',
                                     FS::UI::Web::cust_header(),
                                     'Services',
                                   ],
                  'fields'      => [
                    'pkgnum',
                    sub { my $part_pkg = $part_pkg{shift->pkgpart};
                          $part_pkg->pkg; # ' - '. $part_pkg->comment;
                        },
                    sub { ucfirst(shift->status); },
                    sub { #shift->part_pkg->freq_pretty;
                          my $part_pkg = $part_pkg{shift->pkgpart};
                          $part_pkg->freq_pretty;
                        },

                    #sub { time2str('%b %d %Y', shift->setup); },
                    #sub { time2str('%b %d %Y', shift->last_bill); },
                    #sub { time2str('%b %d %Y', shift->bill); },
                    #sub { time2str('%b %d %Y', shift->susp); },
                    #sub { time2str('%b %d %Y', shift->expire); },
                    #sub { time2str('%b %d %Y', shift->get('cancel')); },
                    ( map { time_or_blank($_) }
                          qw( setup last_bill bill susp expire cancel ) ),

                    \&FS::UI::Web::cust_fields,
                    #sub { '<table border=0 cellspacing=0 cellpadding=0 STYLE="border:none">'.
                    #      join('', map { '<tr><td align="right" style="border:none">'. $_->[0].
                    #                     ':</td><td style="border:none">'. $_->[1]. '</td></tr>' }
                    #                   shift->labels
                    #          ).
                    #      '</table>';
                    #    },
                    sub {
                          [ map {
                                  [ 
                                    { 'data' => $_->[0]. ':',
                                      'align'=> 'right',
                                    },
                                    { 'data' => $_->[1],
                                      'align'=> 'left',
                                      'link' => $p. 'view/' .
                                                $_->[2]. '.cgi?'. $_->[3],
                                    },
                                  ];
                                } shift->labels
                          ];
                        },
                  ],
                  'color' => [
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
                    ( map { '' } FS::UI::Web::cust_header() ),
                    '',
                  ],
                  'style' => [ '', '', 'b' ],
                  'size'  => [ '', '', '-1', ],
                  'align' => 'rlclrrrrrr',
                  'links' => [
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
                    ( map { $clink } FS::UI::Web::cust_header() ),
                    '',
                  ],
              )
%>
