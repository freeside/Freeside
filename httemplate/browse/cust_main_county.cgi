<% include( 'elements/browse.html',
     'title'          => 'Tax Rates',
     'name_singular'  => 'tax rate',
     'html_init'      => $html_init,
     'html_posttotal' => $html_posttotal,
     'query'          => {
                           'table'    => 'cust_main_county',
                           'hashref'  => $hashref,
                           'order_by' =>
                             'ORDER BY country, state, county, taxclass',
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
%
% #         <FONT SIZE=-1><A HREF="<% $p %>edit/process/cust_main_county-collapse.cgi?<% $hashref->{taxnum} %>">collapse state</A></FONT>
% # % } 
%
<%once>

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my @manual_countries = ( 'US', 'CA', 'AU', 'NZ', 'GB' ); #some manual ordering
my @all_countries = ( @manual_countries, 
                      grep { my $c = $_; ! grep { $c eq $_ } @manual_countries }
                      map { $_->country } 
                          qsearch({
                                    'select'    => 'country',
                                    'table'     => 'cust_main_county',
                                    'hashref'   => {},
                                    'extra_sql' => 'GROUP BY country',
                                 })
                    );

my $exempt_sub = sub {
  my $cust_main_county = shift;

  my @exempt = ();
  push @exempt,
       sprintf("$money_char%.2f&nbsp;per&nbsp;month", $cust_main_county->exempt_amount )
    if $cust_main_county->exempt_amount > 0;

  push @exempt, 'Setup&nbsp;fee'
    if $cust_main_county->setuptax =~ /^Y$/i;

  push @exempt, 'Recurring&nbsp;fee'
    if $cust_main_county->recurtax =~ /^Y$/i;

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

#my $edit_link = [ "${p}edit/cust_main_county.html", 'taxnum' ];
my $edit_link = [ 'javascript:void(0);', sub { ''; } ];

my $edit_onclick = sub {
  my $row = shift;
  my $taxnum = $row->taxnum;
  my $color = '#333399';
  qq!overlib( OLiframeContent('${p}edit/cust_main_county.html?$taxnum', 540, 420, 'edit_cust_main_county_popup' ), CAPTION, 'Edit tax rate', STICKY, AUTOSTATUSCAP, MIDX, 0, MIDY, 0, DRAGGABLE, CLOSECLICK, BGCOLOR, '$color', CGCOLOR, '$color' ); return false;!;
};

sub expand_link {
  my( $row, $desc, %opt ) = @_;
  my $taxnum = $row->taxnum;
  $taxnum = "taxclass$taxnum" if $opt{'taxclass'};
  my $color = '#333399';
  qq!<FONT SIZE="-1"><A HREF="javascript:void(0);" onClick="overlib( OLiframeContent('${p}edit/cust_main_county-expand.cgi?$taxnum', 540, 420, 'edit_cust_main_county_popup' ), CAPTION, '$desc', STICKY, AUTOSTATUSCAP, MIDX, 0, MIDY, 0, DRAGGABLE, CLOSECLICK, BGCOLOR, '$color', CGCOLOR, '$color' ); return false;">!;
}

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#my $conf = new FS::Conf;
#my $money_char = $conf->config('money_char') || '$';
my $enable_taxclasses = $conf->exists('enable_taxclasses');

my $html_init =
  "Click on <u>add states</u> to specify a country's tax rates by state or province.
   <BR>Click on <u>add counties</u> to specify a state's tax rates by county.";
$html_init .= "<BR>Click on <u>add taxclasses</u> to specify tax classes."
  if $enable_taxclasses;
$html_init .= '<BR><BR>';

$html_init .= qq(
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_iframe.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/overlibmws_draggable.js"></SCRIPT>
  <SCRIPT TYPE="text/javascript" SRC="${fsurl}elements/iframecontentmws.js"></SCRIPT>
);

my $filter_country = '';
if ( $cgi->param('filter_country') =~ /^(\w\w)$/ ) {
  $filter_country = $1;
}
$cgi->delete('filter_country');
$cgi->param('dummy', 1);

my $country_filter_change =
  "window.location = '".
  $cgi->self_url. ";filter_country=' + this.options[this.selectedIndex].value;";

my $html_posttotal =
  '(show country: '.
  qq(<SELECT NAME="filter_country" onChange="$country_filter_change">).
  qq(<OPTION VALUE="">(all)\n).
  join("\n", map qq[<OPTION VALUE="$_"].
                   ( $_ eq $filter_country ? 'SELECTED' : '' ).
                   '>'. code2country($_). " ($_)",
                 @all_countries
      ).
  '</SELECT>)';

my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM cust_main_county';
if ( $filter_country ) {
  $hashref->{'country'} = $filter_country;
  $count_query .= " WHERE country = '$filter_country'";
}

$cell_style = '';

my @header        = ( 'Country', 'State/Province', 'County',);
my @header2       = ( '', '', '', );
my @links         = ( '', '', '', );
my @link_onclicks = ( '', '', '', );
my $align = 'lll';

my @fields = (
  sub { my $country = shift->country;
        code2country($country). " ($country)";
      },
  sub { state_label($_[0]->state, $_[0]->country).
        ( $_[0]->state
            ? ''
            : '&nbsp'. expand_link($_[0], 'Add States').
                       'add&nbsp;states</A></FONT>'
        )
      },
  sub { $_[0]->county || '(all)&nbsp'.
                         expand_link($_[0], 'Add Counties').
                         'add&nbsp;counties</A></FONT>'
      },
);

my @color = (
  '000000',
  sub { shift->state  ? '000000' : '999999' },
  sub { shift->county ? '000000' : '999999' },
);

if ( $conf->exists('enable_taxclasses') ) {
  push @header,  'Tax class';
  push @header2, '(per-package classification)';
  push @fields,  sub { $_[0]->taxclass || '(all)&nbsp'.
                         expand_link($_[0], 'Add Taxclasses', 'taxclass'=>1).
                         'add&nbsp;taxclasses</A></FONT>'
                     };
  push @color,   sub { shift->taxclass ? '000000' : '999999' };
  push @links,   '';
  push @link_onclicks, '';
  $align .= 'l';
}

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
  sub { shift->tax. '%&nbsp;<FONT SIZE="-1">(edit)</FONT>' },
  $exempt_sub,
;

push @color,
  sub { shift->taxname ? '000000' : '666666' },
  sub { shift->tax     ? '000000' : '666666' },
  '000000',
;

$align .= 'lrl';

my @cell_style = map $cell_style_sub, (1..scalar(@header));

push @links,         '', $edit_link,    '';
push @link_onclicks, '', $edit_onclick, '';

</%init>
