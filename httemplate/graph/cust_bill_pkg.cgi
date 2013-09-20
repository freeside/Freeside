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
                'no_graph'     => \@no_graph,
                'remove_empty' => 1,
                'bottom_total' => 1,
                'bottom_link'  => $bottom_link,
                'agentnum'     => $agentnum,
                'cust_classnum'=> \@cust_classnums,
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

my( $refnum, $sel_part_referral, $all_part_referral ) = ('', '', '');
if ( $cgi->param('refnum') eq 'all' ) {
  $refnum = 0;
  $all_part_referral = 'ALL';
}
elsif ( $cgi->param('refnum') =~ /^(\d+)$/ ) {
  $refnum = $1;
  $bottom_link .= "refnum=$refnum;";
  $sel_part_referral = qsearchs('part_referral', { 'refnum' => $refnum } );
  die "part_referral $refnum not found!" unless $sel_part_referral;
}
$title .= $sel_part_referral->referral.' '
  if $sel_part_referral;

$title .= 'Sales Report (Gross)';
$title .= ', average per customer package'  if $average_per_cust_pkg;

my @cust_classnums = grep /^\d+$/, $cgi->param('cust_classnum');
$bottom_link .= "cust_classnum=$_;" foreach @cust_classnums;

#classnum (here)
# not specified: no longer happens (unless you de-select all classes)
# 0: empty class
# N: classnum
#classnum (link)
# not specified: all classes
# 0: empty class
# N: classnum

#started out as false lazinessish w/FS::cust_pkg::search_sql (previously search/cust_pkg.cgi), but not much left the sane now after #24776

my ($class_table, $name_col, $value_col, $class_param);

if ( $cgi->param('class_mode') eq 'report' ) {
  $class_param = 'report_optionnum'; # CGI param name, also used in the report engine
  $class_table = 'part_pkg_report_option'; # table containing classes
  $name_col = 'name'; # the column of that table containing the label
  $value_col = 'num'; # the column containing the class number
} else {
  $class_param = 'classnum';
  $class_table = 'pkg_class';
  $name_col = 'classname';
  $value_col = 'classnum';
}

my @classnums = grep /^\d+$/, $cgi->param($class_param);
my @classnames = map { if ( $_ ) {
                         my $class = qsearchs($class_table, {$value_col=>$_} );
                         $class->$name_col;
                       } else {
                         '(empty class)';
                       }
                     }
                   @classnums;

$bottom_link .= "$class_param=$_;" foreach @classnums;

if ( $cgi->param('class_agg_break') eq 'aggregate' ) {

  $title .= ' '. join(', ', @classnames)
    unless scalar(@classnames) > scalar(qsearch($class_table,{'disabled'=>''}));
                                 #not efficient for lots of package classes

} elsif ( $cgi->param('class_agg_break') eq 'breakdown' ) {

  if ( $cgi->param('mode') eq 'report' ) {
    # In theory, a package can belong to any subset of the report classes,
    # so the report groups should be all the _subsets_, but for now we're
    # handling the simple case where each package belongs to one report
    # class. Packages with multiple classes will go into one bin at the
    # end.
    push @classnames, '(multiple classes)';
    push @classnums, 'multiple';
  }

} else {
  die "guru meditation #434";
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
my @no_graph;

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

# Categorization of line items goes
# Agent -> Referral -> Package class -> Component (setup/recur/usage)
# If per-agent totals are enabled, they go under the Agent level.
# There aren't any other kinds of subtotals.

foreach my $agent ( $all_agent || $sel_agent || qsearch('agent', { 'disabled' => '' } ) ) {

  my $col_scheme = Color::Scheme->new
                     ->from_hue($hue) #->from_hex($agent->color)
                     ->scheme('analogic')
                   ;
  my @recur_colors = ();
  my @onetime_colors = ();

  ### fixup the color handling for package classes...
  ### and usage

  foreach my $part_referral (
    $all_part_referral ||
    $sel_part_referral ||
    qsearch('part_referral', { 'disabled' => '' } ) 
  ) {

    my @base_params = (
                        'use_override'         => $use_override,
                        'average_per_cust_pkg' => $average_per_cust_pkg,
                        'distribute'           => $distribute,
                      );

    if ( $cgi->param('class_agg_break') eq 'aggregate' ) {

      foreach my $component ( @components ) {

        push @items, 'cust_bill_pkg';

        push @labels,
          ( $all_agent || $sel_agent ? '' : $agent->agent.' ' ).
          ( $all_part_referral || $sel_part_referral ? '' : $part_referral->referral.' ' ).
          $charge_labels{$component};

        my $row_agentnum = $all_agent || $agent->agentnum;
        my $row_refnum = $all_part_referral || $part_referral->refnum;
        push @params, [
                        @base_params,
                        $class_param => \@classnums,
                        ($all_agent ? () : ('agentnum' => $row_agentnum) ),
                        ($all_part_referral ? () : ('refnum' => $row_refnum) ),
                        'charges'              => $component,
                      ];

        my $rowlink = "$link;".
                      ($all_agent ? '' : "agentnum=$row_agentnum;").
                      ($all_part_referral ? '' : "refnum=$row_refnum;").
                      (join('',map {"cust_classnum=$_;"} @cust_classnums)).
                      "distribute=$distribute;".
                      "use_override=$use_override;charges=$component;";
        $rowlink .= "$class_param=$_;" foreach @classnums;
        push @links, $rowlink;

        @recur_colors = ($col_scheme->colors)[0,4,8,1,5,9]
          unless @recur_colors;
        @onetime_colors = ($col_scheme->colors)[2,6,10,3,7,11]
          unless @onetime_colors;
        push @colors, shift @recur_colors;
        push @no_graph, 0;

      } #foreach $component

    } elsif ( $cgi->param('class_agg_break') eq 'breakdown' ) {

      for (my $i = 0; $i < scalar @classnums; $i++) {
        my $row_classnum = $classnums[$i];
        my $row_classname = $classnames[$i];
        foreach my $component ( @components ) {

          push @items, 'cust_bill_pkg';

          push @labels,
            ( $all_agent || $sel_agent ? '' : $agent->agent.' ' ).
            ( $all_part_referral || $sel_part_referral ? '' : $part_referral->referral.' ' ).
            $row_classname .  ' ' . $charge_labels{$component};

          my $row_agentnum = $all_agent || $agent->agentnum;
          my $row_refnum = $all_part_referral || $part_referral->refnum;
          push @params, [
                          @base_params,
                          $class_param => $row_classnum,
                          ($all_agent ? () : ('agentnum' => $row_agentnum) ),
                          ($all_part_referral ? () : ('refnum' => $row_refnum)),
                          'charges'              => $component,
                        ];

          push @links, "$link;".
                       ($all_agent ? '' : "agentnum=$row_agentnum;").
                       ($all_part_referral ? '' : "refnum=$row_refnum;").
                       (join('',map {"cust_classnum=$_;"} @cust_classnums)).
                       "$class_param=$row_classnum;".
                       "distribute=$distribute;".
                       "use_override=$use_override;charges=$component;";

          @recur_colors = ($col_scheme->colors)[0,4,8,1,5,9]
            unless @recur_colors;
          @onetime_colors = ($col_scheme->colors)[2,6,10,3,7,11]
            unless @onetime_colors;
          push @colors, shift @recur_colors;
          push @no_graph, 0;

        } #foreach $component
      } #foreach $row_classnum

    } #$cgi->param('class_agg_break')

  } #foreach $part_referral

  if ( $cgi->param('agent_totals') and !$all_agent ) {
    my $row_agentnum = $agent->agentnum;
    # Include all components that are anywhere on this report
    my $component = join('', @components);

    my @row_params = (  'agentnum'              => $row_agentnum,
                        'cust_classnum'         => \@cust_classnums,
                        'use_override'          => $use_override,
                        'average_per_cust_pkg'  => $average_per_cust_pkg,
                        'distribute'            => $distribute,
                        'charges'               => $component,
                     );
    my $row_link = "$link;".
                   "agentnum=$row_agentnum;".
                   "distribute=$distribute;".
                   "charges=$component;";
    
    # package class filters
    if ( $cgi->param('class_agg_break') eq 'aggregate' ) {
      push @row_params, $class_param => \@classnums;
      $row_link .= "$class_param=$_;" foreach @classnums;
    }

    # refnum filters
    if ( $sel_part_referral ) {
      push @row_params, 'refnum' => $sel_part_referral->refnum;
      $row_link .= "refnum=;".$sel_part_referral->refnum;
    }

    # customer class filters
    $row_link .= "cust_classnum=$_;" foreach @cust_classnums;

    push @items, 'cust_bill_pkg';
    push @labels, mt('[_1] - Subtotal', $agent->agent);
    push @params, \@row_params;
    push @links, $row_link;
    push @colors, '000000'; # better idea?
    push @no_graph, 1;
  }

  $hue += $hue_increment;

}

#use Data::Dumper;
if ( $cgi->param('debug') == 1 ) {
  $FS::Report::Table::DEBUG = 1;
}
</%init>
