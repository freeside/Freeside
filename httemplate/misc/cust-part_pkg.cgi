<% encode_json( \@return ) %>\
<%init>

my( $custnum, $prospectnum, $classnum ) = $cgi->param('arg');

my $agent;
my $cust_main;
if ( $custnum ) {
  $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
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

my $conf = new FS::Conf;

my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $default_start_date = $conf->exists('order_pkg-no_start-date')
                           ? ''
                           : $cust_main->next_bill_date;

my @return = map  {
                    my $start_date = $_->delay_start_date
                                   || $default_start_date;
                    $start_date = time2str($date_format, $start_date)
                      if $start_date;
                    ( $_->pkgpart,
                      $_->pkg_comment,
                      $_->can_discount,
                      $_->can_start_date,
                      $start_date,
                    )
                  }
                  #sort { $a->pkg_comment cmp $b->pkg_comment }
                  @part_pkg;

</%init>
