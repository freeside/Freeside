<% objToJson( \@return ) %>
<%init>

my( $custnum, $prospectnum, $classnum ) = $cgi->param('arg');


my $agent;
if ( $custnum ) {
  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or die 'unknown custnum';
  $agent = $cust_main->agent;
} else {
  my $prospect_main = qsearchs('prospect_main', {'prospectnum'=>$prospectnum} )
    or die 'unknown prospectnum';
  $agent = $prospect_main->agent;
}

my %hash = ( 'disabled' => '' );
if ( $classnum > 0 ) {
  $hash{'classnum'} = $classnum;
} elsif ( $classnum eq '' || $classnum == 0 ) {
  $hash{'classnum'} = '';
} #else -1, all classes, so don't set classnum

my @part_pkg = qsearch({
  'table'     => 'part_pkg',
  'hashref'   => \%hash,
  'extra_sql' =>
    ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql( 'null'=>1 ).
    ' AND '. FS::part_pkg->agent_pkgs_sql( $agent ),
  'order_by'  => 'ORDER BY pkg',
});

my @return = map  { warn $_->can_start_date;
                    ( $_->pkgpart,
                      $_->pkg_comment,
                      $_->can_discount,
                      $_->can_start_date,
                    );
                  }
                  #sort { $a->pkg_comment cmp $b->pkg_comment }
                  @part_pkg;

</%init>
