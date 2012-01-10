<% include('elements/monthly.html',
   #Dumper(
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

my $link = "${p}search/cust_bill_pkg.cgi?nottax=1";
my $bottom_link = "$link;";

my $use_usage = $cgi->param('use_usage') || 0;
my $use_setup = $cgi->param('use_setup') || 0;
my $use_override         = $cgi->param('use_override')         ? 1 : 0;
my $average_per_cust_pkg = $cgi->param('average_per_cust_pkg') ? 1 : 0;
my $distribute           = $cgi->param('distribute')           ? 1 : 0;

my %charge_labels = (
  'SR' => 'setup + recurring',
  'RU' => 'recurring',
  'S'  => 'setup',
  'R'  => 'recurring',
  'U'  => 'usage',
);

#XXX or virtual
my( $agentnum, $sel_agent, $all_agent ) = ('', '', '');
if ( $cgi->param('agentnum') eq 'all' ) {
  $agentnum = 0;
  $all_agent = 'ALL';
}
elsif ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
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
my $all_class = '';
if ( $cgi->param('classnum') eq 'all' ) {
  $all_class = 'ALL';
  @pkg_class = ('');
}
elsif ( $cgi->param('classnum') =~ /^(\d*)$/ ) {
  $classnum = $1;
  if ( $classnum ) { #a specific class

    @pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
    die "classnum $classnum not found!" unless $pkg_class[0];
    $title .= ' '.$pkg_class[0]->classname.' ';
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

my @components = ( 'SRU' );
# split/omit components as appropriate
if ( $use_setup == 1 ) {
  @components = ( 'S', 'RU' );
}
elsif ( $use_setup == 2 ) {
  @components = ( 'RU' );
}
if ( $use_usage == 1 ) {
  $components[-1] =~ s/U//; push @components, 'U';
}
elsif ( $use_usage == 2 ) {
  $components[-1] =~ s/U//;
}

foreach my $agent ( $all_agent || $sel_agent || qsearch('agent', { 'disabled' => '' } ) ) {

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
    foreach my $component ( @components ) {

      push @items, 'cust_bill_pkg';

      push @labels,
        ( $all_agent || $sel_agent ? '' : $agent->agent.' ' ).
        ( $classnum eq '0'
            ? ( ref($pkg_class) ? $pkg_class->classname : $pkg_class ) 
            : ''
        ).
        ' '.$charge_labels{$component};

      my $row_classnum = ref($pkg_class) ? $pkg_class->classnum : 0;
      my $row_agentnum = $all_agent || $agent->agentnum;
      push @params, [ ($all_class ? () : ('classnum' => $row_classnum) ),
                      ($all_agent ? () : ('agentnum' => $row_agentnum) ),
                      'use_override'         => $use_override,
                      'charges'              => $component,
                      'average_per_cust_pkg' => $average_per_cust_pkg,
                      'distribute'           => $distribute,
                    ];

      push @links, "$link;".($all_agent ? '' : "agentnum=$row_agentnum;").
                   ($all_class ? '' : "classnum=$row_classnum;").
                   "distribute=$distribute;".
                   "use_override=$use_override;charges=$component;";

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
if ( $cgi->param('debug') == 1 ) {
  $FS::Report::Table::DEBUG = 1;
}
</%init>
