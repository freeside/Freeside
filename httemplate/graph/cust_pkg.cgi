<& elements/monthly.html,
  'title'         => $agentname. 'Package Churn',
  'items'         => \@items,
  'labels'        => \@labels,
  'graph_labels'  => \@labels,
  'colors'        => \@colors,
  'links'         => \@links,
  'params'        => \@params,
  'agentnum'      => $agentnum,
  'sprintf'       => '%u',
  'disable_money' => 1,
  'remove_empty'  => (scalar(@group_keys) > 1 ? 1 : 0),
&>
<%init>

#XXX use a different ACL for package churn?
my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right('Financial reports');

#false laziness w/money_time.cgi, cust_bill_pkg.cgi

#XXX or virtual
my( $agentnum, $agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $agent;
}

my $agentname = $agent ? $agent->agent.' ' : '';

my @base_items = qw( setup_pkg susp_pkg cancel_pkg );

my %base_labels = (
  'setup_pkg'  => 'New orders',
  'susp_pkg'   => 'Suspensions',
#  'unsusp' => 'Unsuspensions',
  'cancel_pkg' => 'Cancellations',
);

my %base_colors = (
  'setup_pkg'   => '00cc00', #green
  'susp_pkg'    => 'ff9900', #yellow
  #'unsusp'  => '', #light green?
  'cancel_pkg'  => 'cc0000', #red ? 'ff0000'
);

my %base_links = (
  'setup_pkg'  => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'setup_begin',
                    'toparam'   => 'setup_end',
                  },
  'susp_pkg'   => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'susp_begin',
                    'toparam'   => 'susp_end',
                  },
  'cancel_pkg' => { 'link' => "${p}search/cust_pkg.cgi?agentnum=$agentnum;",
                    'fromparam' => 'cancel_begin',
                    'toparam'   => 'cancel_end',
                  },
);

my %filter_params = (
  # not agentnum, that's elsewhere
  'refnum'      => [ $cgi->param('refnum') ],
  'classnum'    => [ $cgi->param('classnum') ],
  'towernum'    => [ $cgi->param('towernum') ],
);
if ( $cgi->param('zip') =~ /^(\w+)/ ) {
  $filter_params{zip} = $1;
}
foreach my $link (values %base_links) {
  foreach my $key (keys(%filter_params)) {
    my $value = $filter_params{$key};
    if (ref($value)) {
      $value = join(',', @$value);
    }
    $link->{'link'} .= "$key=$value;" if length($value);
  }
}


# In order to keep this from being the same trainwreck as cust_bill_pkg.cgi,
# we allow ONE breakdown axis, besides the setup/susp/cancel inherent in 
# the report.

my $breakdown = $cgi->param('breakdown_by');
my ($name_col, $table);
if ($breakdown eq 'classnum') {
  $table = 'pkg_class';
  $name_col = 'classname';
} elsif ($breakdown eq 'refnum') {
  $table = 'part_referral';
  $name_col = 'referral';
} elsif ($breakdown eq 'towernum') {
  $table = 'tower';
  $name_col = 'towername';
} elsif ($breakdown) {
  die "unknown breakdown column '$breakdown'\n";
}

my @group_keys;
my @group_labels;
if ( $table ) {
  my @groups;
  if ( $cgi->param($breakdown) ) {
    foreach my $key ($cgi->param($breakdown)) {
      next if $key =~ /\D/;
      push @groups, qsearch( $table, { $breakdown => $key });
    }
  } else {
    @groups = qsearch( $table );
  }
  foreach (@groups) {
    push @group_keys, $_->get($breakdown);
    push @group_labels, $_->get($name_col);
  }
}

my (@items, @labels, @colors, @links, @params);
if (scalar(@group_keys) > 1) {
  my $hue = 180;
  foreach my $key (@group_keys) {
    # this gives a decent level of contrast as long as there aren't too many
    # result sets
    my $scheme = Color::Scheme->new
      ->scheme('triade')
      ->from_hue($hue)
      ->distance(0.5);
    my $label = shift @group_labels;
    my $i = 0; # item index
    foreach (@base_items) {
      # append the item
      push @items, $_;
      # and its parameters
      push @params, [
        %filter_params,
        $breakdown => $key
      ];
      # and a label prefixed with the group label
      push @labels, "$label - $base_labels{$_}";
      # and colors (?!)
      push @colors, $scheme->colorset->[$i]->[1];
      # and links...
      my %this_link = %{ $base_links{$_} };
      $this_link{link} .= "$breakdown=$key;";
      push @links, \%this_link;
      $i++;
    } #foreach (@base_items
    $hue += 35;
  } # foreach @group_keys
} else {
  @items = @base_items;
  @labels = @base_labels{@base_items};
  @colors = @base_colors{@base_items};
  @links = @base_links{@base_items};
  @params = map { [ %filter_params ] } @base_items;
}

</%init>
