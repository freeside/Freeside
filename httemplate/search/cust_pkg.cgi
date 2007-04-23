<% include( 'elements/search.html',
                  'title'       => 'Package Search Results', 
                  'name'        => 'packages',
                  'query'       => $sql_query,
                  'count_query' => $count_query,
                  #'redirect'    => $link,
                  'header'      => [ '#',
                                     'Package',
                                     'Class',
                                     'Status',
                                     'Freq.',
                                     'Setup',
                                     'Last bill',
                                     'Next bill',
                                     'Susp.',
                                     'Expire',
                                     'Cancel',
                                     FS::UI::Web::cust_header(
                                       $cgi->param('cust_fields')
                                     ),
                                     'Services',
                                   ],
                  'fields'      => [
                    'pkgnum',
                    sub { #my $part_pkg = $part_pkg{shift->pkgpart};
                          #$part_pkg->pkg; # ' - '. $part_pkg->comment;
                          $_[0]->pkg; # ' - '. $_[0]->comment;
                        },
                    'classname',
                    sub { ucfirst(shift->status); },
                    sub { #shift->part_pkg->freq_pretty;

                          #my $part_pkg = $part_pkg{shift->pkgpart};
                          #$part_pkg->freq_pretty;

                          FS::part_pkg::freq_pretty(shift);
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
                    '',
                    sub { shift->statuscolor; },
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
                  'style' => [ '', '', '', 'b', '', '', '', '', '', '', '',
                               FS::UI::Web::cust_styles() ],
                  'size'  => [ '', '', '', '-1', ],
                  'align' => 'rllclrrrrrr'. FS::UI::Web::cust_aligns(). 'r',
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
                    '',
                    ( map { $_ ne 'Cust. Status' ? $clink : '' }
                          FS::UI::Web::cust_header(
                                                    $cgi->param('cust_fields')
                                                  )
                    ),
                    '',
                  ],
              )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List packages');

# my %part_pkg = map { $_->pkgpart => $_ } qsearch('part_pkg', {});

my($query) = $cgi->keywords;

my @where = ();

##
# parse agent
##

if ( $cgi->param('agentnum') =~ /^(\d+)$/ and $1 ) {
  push @where,
    "agentnum = $1";
}

##
# parse status
##

if (    $cgi->param('magic')  eq 'active'
     || $cgi->param('status') eq 'active' ) {

  push @where, FS::cust_pkg->active_sql();

} elsif (    $cgi->param('magic')  eq 'inactive'
          || $cgi->param('status') eq 'inactive' ) {

  push @where, FS::cust_pkg->inactive_sql();


} elsif (    $cgi->param('magic')  eq 'suspended'
          || $cgi->param('status') eq 'suspended'  ) {

  push @where, FS::cust_pkg->suspended_sql();

} elsif (    $cgi->param('magic')  =~ /^cancell?ed$/
          || $cgi->param('status') =~ /^cancell?ed$/ ) {

  push @where, FS::cust_pkg->cancelled_sql();

} elsif ( $cgi->param('status') =~ /^(one-time charge|inactive)$/ ) {

  push @where, FS::cust_pkg->inactive_sql();

}

###
# parse package class
###

#false lazinessish w/graph/cust_bill_pkg.cgi
my $classnum = 0;
my @pkg_class = ();
if ( exists($cgi->Vars->{'classnum'})
     && $cgi->param('classnum') =~ /^(\d*)$/
   )
{
  $classnum = $1;
  if ( $classnum ) { #a specific class
    push @where, "classnum = $classnum";

    #@pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
    #die "classnum $classnum not found!" unless $pkg_class[0];
    #$title .= $pkg_class[0]->classname.' ';

  } elsif ( $classnum eq '' ) { #the empty class

    push @where, "classnum IS NULL";
    #$title .= 'Empty class ';
    #@pkg_class = ( '(empty class)' );
  } elsif ( $classnum eq '0' ) {
    #@pkg_class = qsearch('pkg_class', {} ); # { 'disabled' => '' } );
    #push @pkg_class, '(empty class)';
  } else {
    die "illegal classnum";
  }
}
#eslaf

###
# parse part_pkg
###

my $pkgpart = join (' OR pkgpart=',
                    grep {$_} map { /^(\d+)$/; } ($cgi->param('pkgpart')));
push @where,  '(pkgpart=' . $pkgpart . ')' if $pkgpart;

###
# parse dates
###

my $orderby = '';

#false laziness w/report_cust_pkg.html
my %disable = (
  'all'             => {},
  'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, },
  'active'          => { 'susp'=>1, 'cancel'=>1 },
  'suspended'       => { 'cancel' => 1 },
  'cancelled'       => {},
  ''                => {},
);

foreach my $field (qw( setup last_bill bill susp expire cancel )) {

  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi, $field);

  next if $beginning == 0 && $ending == 4294967295
       or $disable{$cgi->param('status')}->{$field};

  push @where,
    "cust_pkg.$field IS NOT NULL",
    "cust_pkg.$field >= $beginning",
    "cust_pkg.$field <= $ending";

  $orderby ||= "ORDER BY cust_pkg.$field";

}

$orderby ||= 'ORDER BY bill';

###
# parse magic, legacy, etc.
###

if ( $cgi->param('magic') &&
     $cgi->param('magic') =~ /^(active|inactive|suspended|cancell?ed)$/
) {

  $orderby = 'ORDER BY pkgnum';

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
  
}

##
# setup queries, links, subs, etc. for the search
##

# here is the agent virtualization
push @where, $FS::CurrentUser::CurrentUser->agentnums_sql;

my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

my $addl_from = 'LEFT JOIN cust_main USING ( custnum  ) '.
                'LEFT JOIN part_pkg  USING ( pkgpart  ) '.
                'LEFT JOIN pkg_class USING ( classnum ) ';

my $count_query = "SELECT COUNT(*) FROM cust_pkg $addl_from $extra_sql";

my $sql_query = {
  'table'     => 'cust_pkg',
  'hashref'   => {},
  'select'    => join(', ',
                            'cust_pkg.*',
                            ( map "part_pkg.$_", qw( pkg freq ) ),
                            'pkg_class.classname',
                            'cust_main.custnum as cust_main_custnum',
                            FS::UI::Web::cust_sql_fields(
                              $cgi->param('cust_fields')
                            ),
                 ),
  'extra_sql' => "$extra_sql $orderby",
  'addl_from' => $addl_from,
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

</%init>
