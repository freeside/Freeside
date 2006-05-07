<%


#find first month
my $syear = $cgi->param('start_year'); # || 1899+$curyear;
my $smonth = $cgi->param('start_month'); # || $curmon+1;

#find last month
my $eyear = $cgi->param('end_year'); # || 1900+$curyear;
my $emonth = $cgi->param('end_month'); # || $curmon+1;

#XXX or virtual
my( $agentnum, $sel_agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $sel_agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $sel_agent;
}
my $title = $sel_agent ? $sel_agent->agent.' ' : '';

my $classnum = 0;
my @pkg_class = ();
if ( $cgi->param('classnum') =~ /^(\d*)$/ ) {
  $classnum = $1;
  if ( $classnum ) {
    @pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
    die "classnum $classnum not found!" unless $pkg_class[0];
    $title .= $pkg_class[0]->classname.' ';
  } elsif ( $classnum eq '' ) {
    $title .= 'Empty class ';
    @pkg_class = ( '(empty class)' );
  } elsif ( $classnum eq '0' ) {
    @pkg_class = qsearch('pkg_class', {} ); # { 'disabled' => '' } );
    push @pkg_class, '(empty class)';
  }
}

my $hue = 0;
my $hue_increment = 145;

my @items = ();
my @params = ();
my @labels = ();
my @colors = ();

foreach my $agent ( $sel_agent || qsearch('agent', { 'disabled' => '' } ) ) {

  my $col_scheme = Color::Scheme->new
                     ->from_hue($hue)
                     ->scheme('analogic')
                   ;
  my @recur_colors = ();
  my @onetime_colors = ();

  ### fixup the color handling for package classes...
  my $n = 0;

  foreach my $pkg_class ( @pkg_class ) {

    push @items, 'cust_bill_pkg';


    push @labels,
      ( $sel_agent ? '' : $agent->agent.' ' ).
      ( $classnum eq '0'
          ? ( ref($pkg_class) ? $pkg_class->classname : $pkg_class ) 
          : ''
      );

    # push some params
    push @params,
      [ 'classnum' => ( ref($pkg_class) ? $pkg_class->classnum : '' ) ];

    @recur_colors = ($col_scheme->colors)[0,4,8,1,5,9]
      unless @recur_colors;
    @onetime_colors = ($col_scheme->colors)[2,6,10,3,7,11]
      unless @onetime_colors;
    push @colors, shift @recur_colors;

  }

  $hue += $hue_increment;

}

use Data::Dumper;
warn Dumper(\@items);

%><%= include('elements/monthly.html',
                'title'        => $title. 'Sales Report',
                'graph_type'   => 'Mountain',
                'items'        => \@items,
                'params'       => \@params,
                'labels'       => \@labels,
                'graph_labels' => \@labels,
                'colors'       => \@colors,
                #'links'        => \%link,
                'start_month'  => $smonth,
                'start_year'   => $syear,
                'end_month'    => $emonth,
                'end_year'     => $eyear,
                'agentnum'     => $agentnum,
             )
%>
