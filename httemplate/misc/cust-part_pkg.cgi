<% objToJson( \@return ) %>
<%init>

my( $custnum, $classnum ) = $cgi->param('arg');

#XXX i guess i should be agent-virtualized.  cause "packages a customer can
#order" is such a huge deal
my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );

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
    ' AND '. FS::part_pkg->agent_pkgs_sql( $cust_main->agent ),
  'order_by'  => 'ORDER BY pkg',
});

my @return = map  { ( $_->pkgpart, $_->pkg_comment, $_->can_discount ); }
             #sort { $a->pkg_comment cmp $b->pkg_comment }
             @part_pkg;

</%init>
