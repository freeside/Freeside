<% include('elements/monthly.html',
   #Dumper(
                'title'        => $title,
                'graph_type'   => $graph_type,
                'items'        => \@items,
                'params'       => \@params,
                'labels'       => \@labels,
                'graph_labels' => \@labels,
                'colors'       => \@colors,
                'links'        => \@links,
                'no_graph'     => \@no_graph,
                'remove_empty' => 1,
                'bottom_total' => $show_total,
                'nototal'      => !$show_total,
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

my $show_total = 1;
my $graph_type = 'Mountain';

if ( $average_per_cust_pkg ) {
  # then the rows are not additive
  $show_total = 0;
  $graph_type = 'LinesPoints';
}

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
my $all_report_options;

if ( $cgi->param('class_mode') eq 'report' ) {
  $class_param = 'report_optionnum'; # CGI param name, also used in the report engine
  $class_table = 'part_pkg_report_option'; # table containing classes
  $name_col = 'name'; # the column of that table containing the label
  $value_col = 'num'; # the column containing the class number
  # in 'exact' mode we want to run the query in ALL mode.
  # in 'breakdown' mode want to run the query in ALL mode but using the 
  # power set of the classes selected.
  $all_report_options = 1
    unless $cgi->param('class_agg_break') eq 'aggregate';
} else { # class_mode eq 'pkg'
  $class_param = 'classnum';
  $class_table = 'pkg_class';
  $name_col = 'classname';
  $value_col = 'classnum';
}

my @classnums = sort {$a <=> $b} grep /^\d+$/, $cgi->param($class_param);
my @classnames = map { if ( $_ ) {
                         my $class = qsearchs($class_table, {$value_col=>$_} );
                         $class->$name_col;
                       } else {
                         '(empty class)';
                       }
                     }
                   @classnums;
my @not_classnums;

$bottom_link .= "$class_param=$_;" foreach @classnums;

if ( $cgi->param('class_agg_break') eq 'aggregate' or
     $cgi->param('class_agg_break') eq 'exact' ) {

  $title .= ' '. join(', ', @classnames)
    unless scalar(@classnames) > scalar(qsearch($class_table,{'disabled'=>''}));
                                 #not efficient for lots of package classes

} elsif ( $cgi->param('class_agg_break') eq 'breakdown' ) {

  if ( $cgi->param('class_mode') eq 'report' ) {
    # The new way:
    # Actually break down all subsets of the (selected) report classes.
    my @subsets = FS::part_pkg_report_option->subsets(@classnums);
    my @classnum_space = @classnums;
    @classnums = @classnames = ();
    while(@subsets) {
      my $these = shift @subsets;
      # applied topology!
      my $not_these = [ @classnum_space ];
      my $i = 0;
      foreach (@$these) {
        $i++ until $not_these->[$i] == $_;
        splice(@$not_these, $i, 1);
      }
      push @classnums, $these;
      push @not_classnums, $not_these;
      push @classnames, shift @subsets;
    } #while subsets
  }
  # else it's 'pkg', i.e. part_pkg.classnum, which is singular on pkgpart
  # and much simpler

} else {
  die "guru meditation #434";
}

#eslaf

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

my $anum = 0;
foreach my $agent ( $all_agent || $sel_agent || $FS::CurrentUser::CurrentUser->agents ) {

  my @agent_colors = map { my $col = $cgi->param("agent$anum-color$_");
                           $col =~ s/^#//;
                           $col;
                         }
                       (0 .. 5);
  my @colorbuf = ();

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

    if ( $cgi->param('class_agg_break') eq 'aggregate' or
         $cgi->param('class_agg_break') eq 'exact' ) {
      # the only difference between 'aggregate' and 'exact' is whether
      # we pass the 'all_report_options' flag.

      foreach my $component ( @components ) {

        push @items, 'cust_bill_pkg';

        push @labels,
          ( $all_agent || $sel_agent ? '' : $agent->agent.' ' ).
          ( $all_part_referral || $sel_part_referral ? '' : $part_referral->referral.' ' ).
          $charge_labels{$component};

        my $row_agentnum = $all_agent || $agent->agentnum;
        my $row_refnum = $all_part_referral || $part_referral->refnum;
        my @row_params = (
                        @base_params,
                        $class_param => \@classnums,
                        ($all_agent ? () : ('agentnum' => $row_agentnum) ),
                        ($all_part_referral ? () : ('refnum' => $row_refnum) ),
                        'charges'               => $component,
        );

        # XXX this is very silly.  we should cache it server-side and 
        # just put a cache identifier in the link
        my $rowlink = "$link;".
                      ($all_agent ? '' : "agentnum=$row_agentnum;").
                      ($all_part_referral ? '' : "refnum=$row_refnum;").
                      (join('',map {"cust_classnum=$_;"} @cust_classnums)).
                      "distribute=$distribute;".
                      "use_override=$use_override;charges=$component;";
        $rowlink .= "$class_param=$_;" foreach @classnums;
        if ( $all_report_options ) {
          push @row_params, 'all_report_options', 1;
          $rowlink .= 'all_report_options=1';
        }
        push @params, \@row_params;
        push @links, $rowlink;

        @colorbuf = @agent_colors unless @colorbuf;
        push @colors, shift @colorbuf;
        push @no_graph, 0;

      } #foreach $component

    } elsif ( $cgi->param('class_agg_break') eq 'breakdown' ) {

      for (my $i = 0; $i < scalar @classnums; $i++) {
        my $row_classnum = $classnums[$i];
        my $row_classname = $classnames[$i];
        my $not_row_classnum = '';
        if ( $class_param eq 'report_optionnum' ) {
          # if we're working with report options, @classnums here contains 
          # arrays of multiple classnums
          $row_classnum = join(',', @$row_classnum);
          $row_classname = join(', ', @$row_classname);
          $not_row_classnum = join(',', @{ $not_classnums[$i] });
        }
        foreach my $component ( @components ) {

          push @items, 'cust_bill_pkg';

          push @labels,
            ( $all_agent || $sel_agent ? '' : $agent->agent.' ' ).
            ( $all_part_referral || $sel_part_referral ? '' : $part_referral->referral.' ' ).
            $row_classname .  ' ' . $charge_labels{$component};

          my $row_agentnum = $all_agent || $agent->agentnum;
          my $row_refnum = $all_part_referral || $part_referral->refnum;
          my @row_params = (
                          @base_params,
                          $class_param => $row_classnum,
                          ($all_agent ? () : ('agentnum' => $row_agentnum) ),
                          ($all_part_referral ? () : ('refnum' => $row_refnum)),
                          'charges'              => $component,
          );
          my $row_link = "$link;".
                       ($all_agent ? '' : "agentnum=$row_agentnum;").
                       ($all_part_referral ? '' : "refnum=$row_refnum;").
                       (join('',map {"cust_classnum=$_;"} @cust_classnums)).
                       "$class_param=$row_classnum;".
                       "distribute=$distribute;".
                       "use_override=$use_override;charges=$component;";
          if ( $class_param eq 'report_optionnum' ) {
            push @row_params,
                          'all_report_options' => 1,
                          'not_report_optionnum' => $not_row_classnum,
            ;
            $row_link .= "all_report_options=1;".
                         "not_report_optionnum=$not_row_classnum;";
          }
          push @params, \@row_params;
          push @links, $row_link;

          @colorbuf = @agent_colors unless @colorbuf;
          push @colors, shift @colorbuf;
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

  $anum++;

}

# may be useful at some point...
#if ( $average_per_cust_pkg ) {
#  @items = map { ('cust_bill_pkg', 'cust_bill_pkg_count_pkgnum') } @items;
#  @labels = map { $_, "Packages" } @labels;
#  @params = map { $_, $_ } @params;
#  @links = map { $_, $_ } @links;
#  @colors = map { $_, $_ } @colors;
#  @no_graph = map { $_, 1 } @no_graph;
#}
#

#use Data::Dumper;
if ( $cgi->param('debug') == 1 ) {
  $FS::Report::Table::DEBUG = 1;
}
</%init>
