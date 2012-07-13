<% $data %>
<%init>
my $htmldoc = include('report_tax.cgi');

my ($title) = ($htmldoc =~ /<title>\s*(.*)\s*<\/title>/i);

# do this first so we can override the format if it's too many rows
# attribs option: how to locate the table?  It's the only one with class="grid".
my $te = HTML::TableExtract->new(attribs => {class => 'grid'});
$te->parse($htmldoc);
my $table = $te->first_table_found;

my $override = ($table->row_count >= 65536 ? 'XLSX' : '');
my $format = $FS::CurrentUser::CurrentUser->spreadsheet_format($override);
my $filename = 'report_tax'.$format->{extension};

http_header('Content-Type' => $format->{mime_type});
http_header('Content-Disposition' => qq!attachment;filename="$filename"! );

my $data = '';
my $XLS = new IO::Scalar \$data;
my $workbook = $format->{class}->new($XLS)
  or die "Error opening .xls file: $!";

# hardcoded formats, this could be handled better
my $light_gray = $workbook->set_custom_color(63, '#eeeeee');
my %format = (
  title => {
    size      => 24,
    align     => 'center',
    bg_color  => 'silver',
  },
  colhead => {
    size      => 11,
    bold      => 1,
    align     => 'center',
    valign    => 'vcenter',
    text_wrap => 1,
  },
  rowhead => {
    size      => 11,
    valign    => 'bottom',
    text_wrap => 1,
  },
  amount  => {
    size      => 11,
    align     => 'right',
    valign    => 'bottom',
    num_format=> 8,
  },
  'size-1' => {
    size      => 7.5,
    align     => 'center',
    valign    => 'vcenter',
    bold      => 1,
    text_wrap => 1,
  },
  'size+1' => {
    size      => 12,
    align     => 'center',
    valign    => 'vcenter',
    bold      => 1,
  },
  text => {
    size      => 11,
    text_wrap => 1,
  },
);
my %default = (
  font      => 'Calibri',
  bg_color  => $light_gray,
  border    => 1,
);
my @widths = ( #ick
  18, (10.5, 3) x 6, 10.5, 10.5, 3, 10.5, 3, 10.5, 3, 10.5
);
foreach (keys(%format)) {
  my %f = (%default, %{$format{$_}});
  $format{$_} = $workbook->add_format(%f);
  $format{"m_$_"} = $workbook->add_format(%f); # for merged cells
  $format{"t_$_"} = $workbook->add_format(%f, bg_color => 'yellow'); # totals
}
my $ws = $workbook->add_worksheet('taxreport');

my @sheet;
$sheet[0][0] = {
  text    => $title,
  format  => 'title',
  colspan => '18',
};  
# excel position
my $x = 0;
my $y = 3;
foreach my $row ($table->rows()) {
  $x = 0;
  $sheet[$y] = [];
  foreach my $cell (@$row) {
    if ($cell and ref($cell) eq 'HTML::ElementTable::DataElement') {
      my $f = 'text';
      if ( $cell->as_HTML =~ /font/i ) {
        my ($el) = $cell->content_list;
        $f = 'size'.$el->attr('size') if $el->attr('size');
      }
      elsif ( $cell->as_text =~ /^\$/ ) {
        $f = 'amount'
      }
      elsif ( $cell->tag eq 'th' ) {
        $f = 'colhead';
      }
      elsif ( $x == 0 ) {
        $f = 'rowhead';
      }
      $sheet[$y][$x] = {
        text    => $cell->as_text,
        format  => $f,
        rowspan => $cell->attr('rowspan'),
        colspan => $cell->attr('colspan'),
      };
    }
    $x++;
  } #for $cell
  $y++;
}

$y = 0;
foreach my $row (@sheet) {
  $x = 0;
  my $t_row = 1 if($row->[0]->{'text'} eq 'Total');
  foreach my $cell (@$row) {
    if ($cell) {
      my $f = $cell->{format};
      if ($cell->{rowspan} > 1 or $cell->{colspan} > 1) {
        my $range = xl_range_formula(
          'Taxreport', 
          $y,
          $y - 1 + ($cell->{rowspan} || 1),
          $x,
          $x - 1 + ($cell->{colspan} || 1)
        );
        $ws->merge_range($range, $cell->{text}, $format{"m_$f"});
      }
      else {
        $f = "t_$f" if $t_row;
        $ws->write($y, $x, $cell->{text}, $format{$f});
      }
    } #if $cell
    $x++;
  }
  $y++;
}

for my $x (0..scalar(@widths)-1) {
  $ws->set_column($x, $x, $widths[$x]);
}

$workbook->close;

</%init>
