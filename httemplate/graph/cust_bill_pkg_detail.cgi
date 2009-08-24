<% include('elements/monthly.html',
                'title'        => $title. 'Rated Call Sales Report (Gross)',
                'graph_type'   => 'Mountain',
                'items'        => \@items,
                'params'       => \@params,
                'labels'       => \@labels,
                'graph_labels' => \@labels,
                'colors'       => \@colors,
                'remove_empty' => 1,
                'bottom_total' => 1,
                'agentnum'     => $agentnum,
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

#XXX or virtual
my( $agentnum, $sel_agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $sel_agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $sel_agent;
}
my $title = $sel_agent ? $sel_agent->agent.' ' : '';

#false lazinessish w/FS::cust_pkg::search_sql (previously search/cust_pkg.cgi)
my $classnum = '';
if ( $cgi->param('classnum') =~ /^(\d*)$/ ) {
  $classnum = $1;

  if ( $classnum ) { #a specific class

    my $pkg_class = ( qsearchs('pkg_class', { 'classnum' => $classnum } ) );
    die "classnum $classnum not found!" unless $pkg_class;
    $title .= $pkg_class->classname.' ';

  } elsif ( $classnum eq '' ) { #the empty class

    $title .= 'Empty class ';
    # FS::Report::Table::Monthly.pm has the converse view
    $classnum = 0;

  } elsif ( $classnum eq '0' ) { #all classes

    # FS::Report::Table::Monthly.pm has the converse view
    $classnum = '';
  }
}
#eslaf

my $use_override = 0;
$use_override = 1 if ( $cgi->param('use_override') );

my $usageclass = 0;
my @usage_class = ();
if ( $cgi->param('usageclass') =~ /^(\d*)$/ ) {
  $usageclass = $1;

  if ( $usageclass ) { #a specific class

    @usage_class = ( qsearchs('usage_class', { 'classnum' => $usageclass } ) );
    die "usage class $usageclass not found!" unless $usage_class[0];
    $title .= $usage_class[0]->classname.' ';

  } elsif ( $usageclass eq '' ) { #the empty class -- legacy

    $title .= 'Empty usage class ';
    @usage_class = ( '(empty usage class)' );

  } elsif ( $usageclass eq '0' ) { #all classes

    @usage_class = qsearch('usage_class', {} ); # { 'disabled' => '' } );
    push @usage_class, '(empty usage class)';

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

foreach my $agent ( $sel_agent || qsearch('agent', { 'disabled' => '' } ) ) {

  my $col_scheme = Color::Scheme->new
                     ->from_hue($hue) #->from_hex($agent->color)
                     ->scheme('analogic')
                   ;
  my @recur_colors = ();
  my @onetime_colors = ();

  ### fixup the color handling for usage classes...
  my $n = 0;

  foreach my $usage_class ( @usage_class ) {

    push @items, 'cust_bill_pkg_detail';

    push @labels,
      ( $sel_agent ? '' : $agent->agent.' ' ).
      ( $usageclass eq '0'
          ? ( ref($usage_class) ? $usage_class->classname : $usage_class ) 
          : ''
      );

    my $row_classnum = ref($usage_class) ? $usage_class->classnum : 0;
    my $row_agentnum = $agent->agentnum;
    push @params, [ 'usageclass'   => $row_classnum,
                    'agentnum'     => $row_agentnum,
                    'use_override' => $use_override,
                    'classnum'     => $classnum,
                  ];

    @recur_colors = ($col_scheme->colors)[0,4,8,1,5,9]
      unless @recur_colors;
    @onetime_colors = ($col_scheme->colors)[2,6,10,3,7,11]
      unless @onetime_colors;
    push @colors, shift @recur_colors;

  }

  $hue += $hue_increment;

}

#use Data::Dumper;
#warn Dumper(\@items);

</%init>
