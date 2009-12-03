<% include('elements/monthly.html',
                'title'        => $title,
                'graph_type'   => 'Mountain',
                'items'        => \@items,
                'params'       => \@params,
                'labels'       => \@labels,
                'graph_labels' => \@labels,
                'colors'       => \@colors,
                'links'        => \@links,
                'remove_empty' => 1,
                'bottom_total' => 1,
                'bottom_link'  => $bottom_link,
                'agentnum'     => $agentnum,
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $link = "${p}search/cust_bill_pkg.cgi?nottax=1;include_comp_cust=1";
my $bottom_link = "$link;";

my $use_override         = $cgi->param('use_override')         ? 1 : 0;
my $use_usage            = $cgi->param('use_usage')            ? 1 : 0;
my $average_per_cust_pkg = $cgi->param('average_per_cust_pkg') ? 1 : 0;

#XXX or virtual
my( $agentnum, $sel_agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $bottom_link .= "agentnum=$agentnum;";
  $sel_agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $sel_agent;
}
my $title = $sel_agent ? $sel_agent->agent.' ' : '';
$title .= 'Sales Report (Gross)';
$title .= ', average per customer package'  if $average_per_cust_pkg;

#classnum (here)
# 0: all classes
# not specified: empty class
# N: classnum
#classnum (link)
# not specified: all classes
# 0: empty class
# N: classnum

#false lazinessish w/FS::cust_pkg::search_sql (previously search/cust_pkg.cgi)
my $classnum = 0;
my @pkg_class = ();
if ( $cgi->param('classnum') =~ /^(\d*)$/ ) {
  $classnum = $1;

  if ( $classnum ) { #a specific class

    @pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
    die "classnum $classnum not found!" unless $pkg_class[0];
    $title .= $pkg_class[0]->classname.' ';
    $bottom_link .= "classnum=$classnum;";

  } elsif ( $classnum eq '' ) { #the empty class

    $title .= 'Empty class ';
    @pkg_class = ( '(empty class)' );
    $bottom_link .= "classnum=0;";

  } elsif ( $classnum eq '0' ) { #all classes

    @pkg_class = qsearch('pkg_class', {} ); # { 'disabled' => '' } );
    push @pkg_class, '(empty class)';

  }
}
#eslaf

my $hue = 0;
#my $hue_increment = 170;
#my $hue_increment = 145;
my $hue_increment = 125;

my @items  = ();
my @params = ();
my @labels = ();
my @colors = ();
my @links  = ();

foreach my $agent ( $sel_agent || qsearch('agent', { 'disabled' => '' } ) ) {

  my $col_scheme = Color::Scheme->new
                     ->from_hue($hue) #->from_hex($agent->color)
                     ->scheme('analogic')
                   ;
  my @recur_colors = ();
  my @onetime_colors = ();

  ### fixup the color handling for package classes...
  ### and usage
  my $n = 0;

  foreach my $pkg_class ( @pkg_class ) {
    foreach my $component ( $use_usage ? ('recurring', 'usage') : ('') ) {

      push @items, 'cust_bill_pkg';

      push @labels,
        ( $sel_agent ? '' : $agent->agent.' ' ).
        ( $classnum eq '0'
            ? ( ref($pkg_class) ? $pkg_class->classname : $pkg_class ) 
            : ''
        ).
        " $component";

      my $row_classnum = ref($pkg_class) ? $pkg_class->classnum : 0;
      my $row_agentnum = $agent->agentnum;
      push @params, [ 'classnum'             => $row_classnum,
                      'agentnum'             => $row_agentnum,
                      'use_override'         => $use_override,
                      'use_usage'            => $component,
                      'average_per_cust_pkg' => $average_per_cust_pkg,
                    ];

      push @links, "$link;agentnum=$row_agentnum;classnum=$row_classnum;".
                   "use_override=$use_override;use_usage=$component;";

      @recur_colors = ($col_scheme->colors)[0,4,8,1,5,9]
        unless @recur_colors;
      @onetime_colors = ($col_scheme->colors)[2,6,10,3,7,11]
        unless @onetime_colors;
      push @colors, shift @recur_colors;

    }
  }

  $hue += $hue_increment;

}

#use Data::Dumper;
#warn Dumper(\@items);

</%init>
