<% include( 'elements/browse.html',
     'title'          => "Tax Rates $title",
     'name_singular'  => 'tax rate',
     'menubar'        => \@menubar,
     'html_init'      => $html_init,
     'html_form'      => $html_form,
     'query'          => {
                           'table'     => 'tax_rate',
                           'hashref'   => $hashref,
                           'order_by'  => 'ORDER BY geocode, taxclassnum',
                           'extra_sql' => $extra_sql,
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

my $rate_sub = sub {
  my $tax_rate = shift;

  my $units = $tax_rate->unittype_name;
  $units =~ s/ /&nbsp;/g;

  my @rate = ();
  push @rate,
      ($tax_rate->tax * 100). '%&nbsp;<FONT SIZE="-1">(edit)</FONT>'
    if $tax_rate->tax > 0 || $tax_rate->taxbase > 0;
  push @rate,
      ($tax_rate->excessrate * 100). '%&nbsp;<FONT SIZE="-1">(edit)</FONT>'
    if $tax_rate->excessrate > 0;
  push @rate,
      $money_char. $tax_rate->fee.
      qq!&nbsp;per&nbsp;$units<FONT SIZE="-1">(edit)</FONT>!
    if $tax_rate->fee > 0 || $tax_rate->feebase > 0;
  push @rate,
      $money_char. $tax_rate->excessfee.
      qq!&nbsp;per&nbsp;$units<FONT SIZE="-1">(edit)</FONT>!
    if $tax_rate->excessfee > 0;


  [ map [ {'data'=>$_} ], @rate ];
};

my $limit_sub = sub {
  my $tax_rate = shift;

  my $maxtype = $tax_rate->maxtype_name;
  $maxtype =~ s/ /&nbsp;/g;

  my $units = $tax_rate->unittype_name;
  $units =~ s/ /&nbsp;/g;

  my @limit = ();
  push @limit,
       sprintf("$money_char%.2f&nbsp%s", $tax_rate->taxbase, $maxtype )
    if $tax_rate->taxbase > 0;
  push @limit,
       sprintf("$money_char%.2f&nbsp;tax", $tax_rate->taxmax )
    if $tax_rate->taxmax > 0;
  push @limit,
       $tax_rate->feebase. "&nbsp;$units". ($tax_rate->feebase == 1 ? '' : 's')
    if $tax_rate->feebase > 0;
  push @limit,
       $tax_rate->feemax. "&nbsp;$units". ($tax_rate->feebase == 1 ? '' : 's')
    if $tax_rate->feemax > 0;

  push @limit, 'Excluding&nbsp;setup&nbsp;fee'
    if $tax_rate->setuptax =~ /^Y$/i;

  push @limit, 'Excluding&nbsp;recurring&nbsp;fee'
    if $tax_rate->recurtax =~ /^Y$/i;

  [ map [ {'data'=>$_} ], @limit ];
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
  qq!overlib( OLiframeContent('${p}edit/tax_rate.html?$taxnum', 540, 620, 'edit_tax_rate_popup' ), CAPTION, 'Edit tax rate', STICKY, AUTOSTATUSCAP, MIDX, 0, MIDY, 0, DRAGGABLE, CLOSECLICK, BGCOLOR, '$color', CGCOLOR, '$color' ); return false;!;
};

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @menubar;
my $title = '';

my $data_vendor = '';
if ( $cgi->param('data_vendor') =~ /^(\w+)$/ ) {
  $data_vendor = $1;
  $title = "$data_vendor";
}
$cgi->delete('data_vendor');

my $geocode = '';
if ( $cgi->param('geocode') =~ /^(\w+)$/ ) {
  $geocode = $1;
  $title = " geocode $geocode";
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

my $tax_type = $1
  if ( $cgi->param('tax_type') =~ /^(\d+)$/ );
my $tax_cat = $1
  if ( $cgi->param('tax_cat') =~ /^(\d+)$/ );

my @taxclassnum = ();
if ($tax_type || $tax_cat ) {
  my $compare = "LIKE '". ( $tax_type || "%" ). ":". ( $tax_cat || "%" ). "'";
  $compare = "= '$tax_type:$tax_cat'" if ($tax_type && $tax_cat);
  my @tax_class =
    qsearch({ 'table'     => 'tax_class',
              'hashref'   => {},
              'extra_sql' => "WHERE taxclass $compare",
           });
  if (@tax_class) {
    @taxclassnum = map { $_->taxclassnum } @tax_class;
    $tax_class[0]->description =~ /^(.*):(.*)/;
    $title .= " for";
    $title .= " $tax_type ($1) tax type" if $tax_type;
    $title .= " and" if ($tax_type && $tax_cat);
    $title .= " $tax_cat ($2) tax category" if $tax_cat;
  }else{
    $tax_type = '';
    $tax_cat = '';
  }
}
$cgi->delete('tax_type');
$cgi->delete('tax_cat');

if ( $geocode || $taxclassnum ) {
  push @menubar, 'View all tax rates' => $p.'browse/tax_rate.cgi';
}

$cgi->param('dummy', 1);

#restore this so pagination works
$cgi->param('data_vendor',  $data_vendor) if $data_vendor;
$cgi->param('geocode',  $geocode) if $geocode;
$cgi->param('taxclassnum', $taxclassnum ) if $taxclassnum;
$cgi->param('tax_type', $tax_type ) if $tax_type;
$cgi->param('tax_cat', $tax_cat ) if $tax_cat;

my $html_form = include('/elements/init_overlib.html'). '<BR><BR>'.
  join(' ',
    map {
      include('/elements/popup_link.html',
               {
                 'action' => $p. "misc/enable_or_disable_tax.html?action=$_&".
                             $cgi->query_string,
                 'label' => ucfirst($_). ' all these taxes',
                 'actionlabel' => ucfirst($_). ' taxes',
               },
             );
    }
    qw(disable enable)
  );

my $hashref = {};
my $extra_sql = '';
if ( $data_vendor ) {
  $extra_sql .= ' WHERE data_vendor = '. dbh->quote($data_vendor);
}

if ( $geocode ) {
  $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                ' geocode LIKE '. dbh->quote($geocode.'%');
}

if ( $taxclassnum ) {
  $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                ' taxclassnum  = '. dbh->quote($taxclassnum);
}

if ( @taxclassnum ) {
  $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                join(' OR ', map { " taxclassnum  = $_ " } @taxclassnum );
}

my $count_query = "SELECT COUNT(*) FROM tax_rate $extra_sql";

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
push @fields, 'taxclass_description';
push @color, '000000';
push @links, '';
push @link_onclicks, '';
$align .= 'l';

push @header, 'Tax name',
              'Rate', #'Tax',
              'Limits',
              ;

push @header2, '(printed on invoices)',
               '',
               '',
               ;

push @fields, 
  sub { shift->taxname || 'Tax' },
  $rate_sub,
  $limit_sub,
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

my $html_init = '';

$html_init .= qq(
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_iframe.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_draggable.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/iframecontentmws.js"></SCRIPT>

);

$html_init .= qq(
  <FORM>
    <TABLE>
      <TR>
        <TD><SELECT NAME="data_vendor" onChange="this.form.submit()">
);

my $sql = "SELECT DISTINCT data_vendor FROM tax_rate ORDER BY data_vendor";
my $dbh = dbh;
my $sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (['(choose data vendor)'], @{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                ($_->[0] eq $data_vendor ? " SELECTED" : "").
                '">'.  $_->[0];
}
$html_init .= qq(
        </SELECT>

        <TD><INPUT NAME="geocode" TYPE="text" SIZE="12" VALUE="$geocode"></TD>

<!-- generic
        <TD><INPUT NAME="taxclassnum" TYPE="text" SIZE="12" VALUE="$taxclassnum"></TD>
        <TD><INPUT TYPE="submit" VALUE="Filter by tax_class"></TD>
-->

<!-- cch specific -->
        <TD><SELECT NAME="tax_type" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       "substring(taxclass from 1 for position(':' in taxclass)-1),".
       "substring(description from 1 for position(':' in description)-1) ".
       "FROM tax_class WHERE data_vendor='cch' ORDER BY 2";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (['', '(choose tax type)'], @{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_type ? " SELECTED" : "").
                 '">'. $_->[1];
}

$html_init .= qq(
        </SELECT>

        <TD><SELECT NAME="tax_cat" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       "substring(taxclass from position(':' in taxclass)+1),".
       "substring(description from position(':' in description)+1) ".
       "from tax_class WHERE data_vendor='cch' ORDER BY 2";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (['', '(choose tax category)'], @{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_cat ? " SELECTED" : "").
                 '">'.  $_->[1];
}

$html_init .= qq(
        </SELECT>

      </TR>
      <TR>
        <TD></TD>
        <TD><INPUT TYPE="submit" VALUE="Filter by geocode"></TD>
        <TD></TD>
        <TD></TD>
      </TR>
    </TABLE>
  </FORM>

);

</%init>
