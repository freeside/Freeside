<% include( 'elements/browse.html',
     'title'          => "Tax Rates $title",
     'name_singular'  => 'tax rate',
     'menubar'        => \@menubar,
     'html_init'      => $html_init,
     'query'          => {
                           'table'    => 'tax_rate',
                           'hashref'  => $hashref,
                           'order_by' => 'ORDER BY geocode, taxclassnum',
                         },
     'count_query'    => $count_query,
     'header'         => \@header,
     'header2'        => \@header2,
     'fields'         => \@fields,
     'align'          => $align,
     'color'          => \@color,
     'cell_style'     => \@cell_style,
     'links'          => \@links,
     'link_onclicks'  => \@link_onclicks,
  )
%>
<%once>

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my $exempt_sub = sub {
  my $tax_rate = shift;

  my @exempt = ();
  push @exempt,
       sprintf("$money_char%.2f&nbsp;per&nbsp;month", $tax_rate->exempt_amount )
    if $tax_rate->exempt_amount > 0;

  push @exempt, 'Setup&nbsp;fee'
    if $tax_rate->setuptax =~ /^Y$/i;

  push @exempt, 'Recurring&nbsp;fee'
    if $tax_rate->recurtax =~ /^Y$/i;

  [ map [ {'data'=>$_} ], @exempt ];
};

my $oldrow;
my $cell_style;
my $cell_style_sub = sub {
  my $row = shift;
  if ( $oldrow ne $row ) {
    if ( $oldrow ) {
      if ( $oldrow->country ne $row->country ) {
        $cell_style = 'border-top:1px solid #000000';
      } elsif ( $oldrow->state ne $row->state ) {
        $cell_style = 'border-top:1px solid #cccccc'; #default?
      } elsif ( $oldrow->state eq $row->state ) {
        #$cell_style = 'border-top:dashed 1px dark gray';
        $cell_style = 'border-top:1px dashed #cccccc';
      }
    }
    $oldrow = $row;
  }
  return $cell_style;
};

my $select_link = [ 'javascript:void(0);', sub { ''; } ];

my $select_onclick = sub {
  my $row = shift;
  my $taxnum = $row->taxnum;
  my $color = '#333399';
  qq!overlib( OLiframeContent('${p}edit/tax_rate.html?$taxnum', 540, 420, 'edit_tax_rate_popup' ), CAPTION, 'Edit tax rate', STICKY, AUTOSTATUSCAP, MIDX, 0, MIDY, 0, DRAGGABLE, CLOSECLICK, BGCOLOR, '$color', CGCOLOR, '$color' ); return false;!;
};

my $separate_taxclasses_link  = sub {
  my( $row ) = @_;
  my $taxnum = $row->taxnum;
  my $url = "${p}edit/process/tax_rate-expand.cgi?taxclassnum=1;taxnum=$taxnum";

  qq!<FONT SIZE="-1"><A HREF="$url">!;
};

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @menubar;

my $html_init =
  "Click on <u>geocodes</u> to specify rates for a new area.";
$html_init .= "<BR>Click on <u>separate taxclasses</u> to specify taxes per taxclass.";
$html_init .= '<BR><BR>';

$html_init .= qq(
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_iframe.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_draggable.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/iframecontentmws.js"></SCRIPT>
);

my $title = '';
my $select_word = 'edit';

my $geocode = '';
if ( $cgi->param('geocode') =~ /^(\w+)$/ ) {
  $geocode = $1;
  $title = "$geocode";
}
$cgi->delete('geocode');

$title = " for $title" if $title;

my $taxclassnum = '';
if ( $cgi->param('taxclassnum') =~ /^(\d+)$/ ) {
  $taxclassnum = $1;
  my $tax_class = qsearchs('tax_class', {'taxclassnum' => $taxclassnum});
  if ($tax_class) {
    $title .= " for ". $tax_class->taxclass.
              " (".  $tax_class->description. ") tax class";
  }else{
    $taxclassnum = '';
  }
}
$cgi->delete('taxclassnum');

if ( $geocode || $taxclassnum ) {
  push @menubar, 'View all tax rates' => $p.'browse/tax_rate.cgi';
}

$cgi->param('dummy', 1);

#restore this so pagination works
$cgi->param('geocode',  $geocode) if $geocode;
$cgi->param('taxclassnum', $taxclassnum ) if $taxclassnum;

my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM tax_rate';
if ( $geocode ) {
  $hashref->{'geocode'} = $geocode;
  $count_query .= ' WHERE geocode = '. dbh->quote($geocode);
}
if ( $taxclassnum ) {
  $hashref->{'taxclassnum'} = $taxclassnum;
  $count_query .= ( $count_query =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                  ' taxclassnum  = '. dbh->quote($taxclassnum);
}


$cell_style = '';

my @header        = ( 'Location Code',  );
my @header2       = ( '', );
my @links         = ( '', );
my @link_onclicks = ( '', );
my $align = 'l';

my @fields = (
  'geocode',
);

my @color = (
  '000000',
);

push @header, qq!Tax class (<A HREF="${p}edit/tax_class.html">add new</A>)!;
push @header2, '(per-tax classification)';
push @fields, sub { $_[0]->taxclass_description || '(all)&nbsp'.
                     &{$separate_taxclasses_link}($_[0], 'Separate Taxclasses').
                     'separate&nbsp;taxclasses</A></FONT>'
                  };
push @color, sub { shift->taxclass ? '000000' : '999999' };
push @links, '';
push @link_onclicks, '';
$align .= 'l';

push @header, 'Tax name',
              'Rate', #'Tax',
              'Exemptions',
              ;

push @header2, '(printed on invoices)',
               '',
               '',
               ;

push @fields, 
  sub { shift->taxname || 'Tax' },
  sub { shift->tax. '%&nbsp;<FONT SIZE="-1">('. $select_word. ')</FONT>' },
  $exempt_sub,
;

push @color,
  sub { shift->taxname ? '000000' : '666666' },
  sub { shift->tax     ? '000000' : '666666' },
  '000000',
;

$align .= 'lrl';

my @cell_style = map $cell_style_sub, (1..scalar(@header));

push @links,         '', $select_link,    '';
push @link_onclicks, '', $select_onclick, '';

</%init>
