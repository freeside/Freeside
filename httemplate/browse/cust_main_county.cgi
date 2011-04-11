<% include( 'elements/browse.html',
     'title'          => "Tax Rates $title",
     'name_singular'  => 'tax rate',
     'menubar'        => \@menubar,
     'html_init'      => $html_init,
     'html_posttotal' => $html_posttotal,
     'html_form'      => '<FORM NAME="taxesForm">',
     'html_foot'      => $html_foot,
     'query'          => {
                           'table'    => 'cust_main_county',
                           'hashref'  => $hashref,
                           'order_by' =>
                             'ORDER BY country, state, county, city, taxclass',
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

my $cs_oldrow;
my $cell_style = '';
my $cell_style_sub = sub {
  my $row = shift;
  if ( $cs_oldrow ne $row ) {
    if ( $cs_oldrow ) {
      if ( $cs_oldrow->country ne $row->country ) {
        $cell_style = 'border-top:2px solid #000000';
      } elsif ( $cs_oldrow->state ne $row->state ) {
        $cell_style = 'border-top:1px solid #888888';
      } elsif ( $cs_oldrow->county ne $row->county ) {
        $cell_style = 'border-top:1px solid #cccccc';
      } else { 
        $cell_style = '';
      }
    }
    $cs_oldrow = $row;
  }
  return $cell_style;
};

#my $edit_link = [ "${p}edit/cust_main_county.html", 'taxnum' ];
my $edit_link = [ 'javascript:void(0);', sub { ''; } ];

my $edit_onclick = sub {
  my $row = shift;
  my $taxnum = $row->taxnum;
  include( '/elements/popup_link_onclick.html',
             'action'      => "${p}edit/cust_main_county.html?$taxnum",
             'actionlabel' => 'Edit tax rate',
             'height'      => 420,
             #default# 'width'  => 540,
             #default# 'color' => '#333399',
         );
};

my $ex_oldrow;
sub expand_link {
  my %param = @_;

  if ( $ex_oldrow eq $param{'row'} ) {
    return '';
  } else {
    $ex_oldrow = $param{'row'};
  }

  my $taxnum = $param{'row'}->taxnum;
  my $url = "${p}edit/cust_main_county-expand.cgi?$taxnum";

  '<FONT SIZE="-1">'.
    include( '/elements/popup_link.html',
               'label'       => $param{'label'},
               'action'      => $url,
               'actionlabel' => $param{'desc'},
               'height'      => 420,
               #default# 'width'  => 540,
               #default# 'color' => '#333399',
           ).
  '</FONT>';
}

sub add_link {
  my %param = @_;

  #if ( $ex_oldrow eq $param{'row'} ) {
  #  return '';
  #} else {
  #  $ex_oldrow = $param{'row'};
  #}

  my %below = ( 'county' => 'city',
                'state'  => 'county',
              );
  my $what = $below{ $param{'col' } };

  my $taxnum = $param{'row'}->taxnum;
  my $url = "${p}edit/cust_main_county-add.cgi?taxnum=$taxnum;what=$what";

  '<FONT SIZE="-1">'.
    include( '/elements/popup_link.html',
               'label'       => $param{'label'},
               'action'      => $url,
               'actionlabel' => $param{'desc'},
               'height'      => 420,
               #default# 'width'  => 540,
               #default# 'color' => '#333399',
           ).
  '</FONT>';
}

sub collapse_link {
  my %param = @_;

  my $row = $param{'row'};
  my $col = $param{'col'};
#  return ''
#    if $col eq 'state' and $row->city
#                            || qsearch({
#                                 'table'   => 'cust_main_county',
#                                 'hashref' => {
#                                   'country' => $row->country,
#                                   'state'   => $row->state,
#                                   'city'    => { op=>'!=', value=>'' },
#                                 },
#                                 'order_by' => 'LIMIT 1',
#                               });

  my %below = ( 'county' => 'city',
                'state'  => 'county',
              );

  #XXX can still show the link when you have some counties broken down into
  #cities and others not :/

  my $taxnum = $param{'row'}->taxnum;
  my $url = "${p}edit/process/cust_main_county-collapse.cgi?taxnum=$taxnum;".
              'country='. uri_escape($cgi->param('country')). ';'.
              'state='.   uri_escape($cgi->param('state')).   ';'.
              'county='.  uri_escape($cgi->param('county'));
  $url = "javascript:collapse_areyousure('$url', '$below{$col}', '$col')";

  qq(<FONT SIZE="-1"><A HREF="$url">$param{'label'}</A></FONT>);
}

sub remove_link {
  my %param = @_;

  my $row = $param{'row'};
  my $col = $param{'col'};
 
  my $taxnum = $param{'row'}->taxnum;
  my $url = "${p}edit/process/cust_main_county-remove.cgi?taxnum=$taxnum;".
              'country='. uri_escape($cgi->param('country')). ';'.
              'state='.   uri_escape($cgi->param('state')).   ';'.
              'county='.  uri_escape($cgi->param('county'));
  $url = "javascript:remove_areyousure('$url', '$col')";

  qq(<FONT SIZE="-1"><A HREF="$url">$param{'label'}</A></FONT>);

}

sub separate_taxclasses_link {
  my( $row ) = @_;
  my $taxnum = $row->taxnum;
  my $url = "${p}edit/process/cust_main_county-expand.cgi?taxclass=1;taxnum=$taxnum";

  qq!<FONT SIZE="-1"><A HREF="$url">!;
}

#un-separate taxclasses too

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#my $conf = new FS::Conf;
#my $money_char = $conf->config('money_char') || '$';
my $enable_taxclasses = $conf->exists('enable_taxclasses');

my @menubar;

my $html_init = <<END;
  <SCRIPT>
    function collapse_areyousure(href,col,above) {
     if (confirm('Are you sure you want to remove all ' + col + ' tax rates for this ' + above + '?') == true)
       window.location.href = href;
    }
    function remove_areyousure(href,col) {
     if (confirm('Are you sure you want to remove this ' + col + '?') == true)
       window.location.href = href;
    }
  </SCRIPT>
END

$html_init .= "<BR>Click on <u>separate taxclasses</u> to specify taxes per taxclass."
  if $enable_taxclasses;
$html_init .= '<BR><BR>';

$html_init .= include('/elements/init_overlib.html');

my $title = '';

my $country = '';
if ( $cgi->param('country') =~ /^(\w\w)$/ ) {
  $country = $1;
  $title = $country;
}
$cgi->delete('country');

my $state = '';
if ( $country && $cgi->param('state') =~ /^([\w \-\'\[\]]+)$/ ) {
  $state = $1;
  $title = "$state, $title";
}
$cgi->delete('state');

my $county = '';
if ( $country && $state &&
     $cgi->param('county') =~
       /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=\[\]]+)$/
   )
{
  $county = $1;
  if ( $county eq '__NONE__' ) {
    $title = "No county, $title";
  } else {
    $title = "$county county, $title";
  }
}
$cgi->delete('county');

$title = " for $title" if $title;

my $taxclass = '';
if ( $cgi->param('taxclass') =~ /^([\w \-]+)$/ ) {
  $taxclass = $1;
  $title .= " for $taxclass tax class";
}
$cgi->delete('taxclass');

if ( $country || $taxclass ) {
  push @menubar, 'View all tax rates' => $p.'browse/cust_main_county.cgi';
}

$cgi->param('dummy', 1);

my $filter_change =
  "window.location = '". $cgi->self_url.
  ";country=' + encodeURIComponent( document.getElementById('country').options[document.getElementById('country').selectedIndex].value ) + ".
  "';state='   + encodeURIComponent( document.getElementById('state').options[document.getElementById('state').selectedIndex].value ) +".
  "';county='  + encodeURIComponent( document.getElementById('county').options[document.getElementById('county').selectedIndex].value );";

#restore this so pagination works
$cgi->param('country',  $country) if $country;
$cgi->param('state',    $state  ) if $state;
$cgi->param('county',   $county ) if $county;
$cgi->param('taxclass', $county ) if $taxclass;

my $html_posttotal =
  '<BR>( show country: '.
  include('/elements/select-country.html',
            'country'             => $country,
            'onchange'            => $filter_change,
            'empty_label'         => '(all)',
            'disable_empty'       => 0,
            'disable_stateupdate' => 1,
         );

my %states_hash = $country ? states_hash($country) : ();
if ( scalar(keys(%states_hash)) > 1 ) {
  $html_posttotal .=
    ' show state: '.
    include('/elements/select-state.html',
              'country'              => $country,
              'state'                => $state,
              'onchange'             => $filter_change,
              'empty_label'          => '(all)',
              'disable_empty'        => 0,
              'disable_countyupdate' => 1,
           );
} else {
  $html_posttotal .=
    '<SELECT NAME="state" ID="state" STYLE="display:none">'.
    '  <OPTION VALUE="" SELECTED>'.
    '</SELECT>';
}

my @counties = ( $country && $state ) ? counties($state, $country) : ();
if ( scalar(@counties) > 1 ) {
  $html_posttotal .=
    ' show county: '.
    include('/elements/select-county.html',
              'country'              => $country,
              'state'                => $state,
              'county'               => $county,
              'onchange'             => $filter_change,
              'empty_label'          => '(all)',
              'empty_data_label'     => '(none)',
              'empty_data_value'     => '__NONE__',
              'disable_empty'        => 0,
              'disable_cityupdate'   => 1,
           );
} else {
  $html_posttotal .=
    '<SELECT NAME="county" ID="county" STYLE="display:none">'.
    '  <OPTION VALUE="" SELECTED>'.
    '</SELECT>';
}

$html_posttotal .= ' )';

my $bulk_popup_link = 
  include( '/elements/popup_link_onclick.html',
             'action'      => "${p}edit/bulk-cust_main_county.html?taxnum=MAGIC_taxnum_MAGIC",
             'actionlabel' => 'Bulk add new tax',
             'nofalse'     => 1,
             'height'      => 420,
             #default# 'width'  => 540,
             #default# 'color' => '#333399',
         );

my $html_foot = <<END;
<SCRIPT TYPE="text/javascript">

  function setAll(setTo) {
    theForm = document.taxesForm;
    for (i=0,n=theForm.elements.length;i<n;i++) {
      if (theForm.elements[i].name.indexOf("cust_main_county") != -1) {
        theForm.elements[i].checked = setTo;
      }
    }
  }

  function toggleAll() {
    theForm = document.taxesForm;
    for (i=0,n=theForm.elements.length;i<n;i++) {
      if (theForm.elements[i].name.indexOf("cust_main_county") != -1) {
        if ( theForm.elements[i].checked == true ) {
          theForm.elements[i].checked = false;
        } else {
          theForm.elements[i].checked = true;
        }
      }
    }
  }

  function bulkPopup(action) {
    var bulk_popup_link = "$bulk_popup_link";
    var bulkstring = '';
    theForm = document.taxesForm;
    for (i=0,n=theForm.elements.length;i<n;i++) {
      if (    theForm.elements[i].name.indexOf("cust_main_county") != -1
           && theForm.elements[i].checked == true
         ) {
        var name = theForm.elements[i].name;
        var taxnum = name.replace(/cust_main_county/, '');
        if ( bulkstring != '' ) {
          bulkstring = bulkstring + ',';
        }
        bulkstring = bulkstring + taxnum;
       
      }
    }
    bulkstring = bulkstring + ';action=' + action;
    if ( bulk_popup_link.length > 1920 ) { // IE 2083 URL limit
      alert('Too many selections'); // should do some session thing...
      return false;
    }
    bulk_popup_link = bulk_popup_link.replace(/MAGIC_taxnum_MAGIC/, bulkstring);
    eval(bulk_popup_link);
  }

</SCRIPT>

<BR>
<A HREF="javascript:setAll(true)">select all</A> |
<A HREF="javascript:setAll(false)">unselect all</A> |
<A HREF="javascript:toggleAll()">toggle all</A>
<BR><BR>
<A HREF="javascript:void(0);" onClick="bulkPopup('add');">Add new tax to selected</A>
|
<A HREF="javascript:void(0);" onClick="bulkPopup('edit');">Bulk edit selected</A>

END

my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM cust_main_county';
if ( $country ) {
  $hashref->{'country'} = $country;
  $count_query .= ' WHERE country = '. dbh->quote($country);
}
if ( $state ) {
  $hashref->{'state'} = $state;
  $count_query .= ' AND state   = '. dbh->quote($state);
}
if ( $county ) {
  if ( $county eq '__NONE__' ) {
    $hashref->{'county'} = '';
    $count_query .= " AND ( county = '' OR county IS NULL ) ";
  } else {
    $hashref->{'county'} = $county;
    $count_query .= ' AND county  = '. dbh->quote($county);
  }
}
if ( $taxclass ) {
  $hashref->{'taxclass'} = $taxclass;
  $count_query .= ( $count_query =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                  ' taxclass  = '. dbh->quote($taxclass);
}


$cell_style = '';

my @header        = ( 'Country', 'State/Province', 'County', 'City' );
my @header2       = ( '', '', '', '', );
my @links         = ( '', '', '', '', );
my @link_onclicks = ( '', '', '', '', );
my $align = 'llll';

my %seen_country = ();
my %seen_state = ();
my %seen_county = ();

my @fields = (
  sub { my $country = shift->country;
        return '' if $seen_country{$country}++;
        code2country($country). "&nbsp;($country)";
      },

  #state
  sub { my $label = $seen_state{$_[0]->country}->{$_[0]->state}++
                      ? '' : state_label($_[0]->state, $_[0]->country);

        my $countylinks = ( $_[0]->county && $label )
                             ? '&nbsp;'. add_link(
                                 desc => 'Add more counties',
                                 col  => 'state',
                                 label=> 'add&nbsp;more&nbsp;counties',
                                 row  => $_[0],
                                 cgi  => $cgi,
                               ).
                               ' '. collapse_link(
                                 col  => 'state',
                                 label=> 'remove&nbsp;all&nbsp;counties',
                                 row  => $_[0],
                                 cgi  => $cgi,
                               )
                             : '';

        my $addlink = 
          ( $_[0]->state
              ? ''
              : '&nbsp;'. expand_link( desc  => 'Add States',
                                       row   => $_[0],
                                       label => 'add&nbsp;states',
                                       cgi  => $cgi,
                                     )
          );

        $label.$countylinks.$addlink;
      },

  #county
  sub { my $label =
          $seen_county{$_[0]->country}->{$_[0]->state}->{$_[0]->county}++ 
            ? '' : $_[0]->county;

        my $citylinks = '';
        if ( $label ) {
          $citylinks = $_[0]->city
                       ? '&nbsp;'. add_link(
                           desc => 'Add more cities',
                           col  => 'county',
                           label=> 'add&nbsp;more&nbsp;cities',
                           row  => $_[0],
                           cgi  => $cgi,
                         ).
                         ' '. collapse_link(
                           col  => 'county',
                           label=> 'remove&nbsp;all&nbsp;cities',
                           row  => $_[0],
                           cgi  => $cgi,
                         )
                       : '&nbsp;'. remove_link( col  => 'county',
                                                label=> 'remove&nbsp;county',
                                                row  => $_[0],
                                                cgi  => $cgi,
                                              );
        }

        $_[0]->county
          ? $label.$citylinks
          : '(all)&nbsp;'.
              expand_link(   desc  => 'Add Counties',
                             row   => $_[0],
                             label => 'add&nbsp;counties',
                             cgi  => $cgi,
                         );
      },

  #city
  sub {
        my $r = shift;
        if ( $r->city ) {

          if ( $r->taxclass ) { #but if it has a taxclass, can't remove
            $r->city;
          } else {
            $r->city. '&nbsp;'.
              remove_link( col  => 'city',
                           label=> 'remove&nbsp;city',
                           row  => $r,
                           cgi  => $cgi,
                         );
          }
        } else {
          '(all)&nbsp;'.
            expand_link(   desc  => 'Add Cities',
                           row   => $r,
                           label => 'add&nbsp;cities',
                           cgi  => $cgi,
                       );
        }
      },
);

my @color = (
  '000000',
  sub { shift->state  ? '000000' : '999999' },
  sub { shift->county ? '000000' : '999999' },
  sub { shift->city   ? '000000' : '999999' },
);

if ( $conf->exists('enable_taxclasses') ) {
  push @header, qq!Tax class (<A HREF="${p}edit/part_pkg_taxclass.html">add new</A>)!;
  push @header2, '(per-package classification)';
  push @fields, sub {
    my $r = shift;
    if ( $r->taxclass ) {
      $r->taxclass;
    } else {
      my $sql = 'SELECT COUNT(*) FROM cust_main_county
                   WHERE country = ? AND state = ? AND county = ?
                     AND city = ? AND taxclass IS NOT NULL';
      if ( FS::Record->scalar_sql($sql, map $r->$_,
                                            qw( country state county city) ) ) {
        '(none)';
      } else {
        '(all)&nbsp;'.
          separate_taxclasses_link($r, 'Separate Taxclasses').
          'separate&nbsp;taxclasses</A></FONT>';
      }
    }
  };
  push @color, sub { shift->taxclass ? '000000' : '999999' };
  push @links, '';
  push @link_onclicks, '';
  $align .= 'l';
}

push @header,
              '', #checkbox column
              'Tax name',
              'Rate', #'Tax',
              'Exemptions',
              ;

push @header2,
               '',
               '(printed on invoices)',
               '',
               '',
               ;

my $newregion = 1;
my $cb_oldrow = '';
my $cb_sub = sub {
  my $cust_main_county = shift;

  if ( $cb_oldrow ) {
    if (    $cb_oldrow->city     ne $cust_main_county->city 
         || $cb_oldrow->county   ne $cust_main_county->county  
         || $cb_oldrow->state    ne $cust_main_county->state  
         || $cb_oldrow->country  ne $cust_main_county->country 
         || $cb_oldrow->taxclass ne $cust_main_county->taxclass )
    {
      $newregion = 1;
    } else {
      $newregion = 0;
    }  
    
  } else {
    $newregion = 1;
  }
  $cb_oldrow = $cust_main_county;

  if ( $newregion ) {
    my $taxnum = $cust_main_county->taxnum;
    qq!<INPUT NAME="cust_main_county$taxnum" TYPE="checkbox" VALUE="1">!;
  } else {
    '';
  }
};

push @fields, 
  $cb_sub,
  sub { shift->taxname || 'Tax' },
  sub { shift->tax. '%&nbsp;<FONT SIZE="-1">(edit)</FONT>' },
  $exempt_sub,
;

push @color,
  '000000',
  sub { shift->taxname ? '000000' : '666666' },
  sub { shift->tax     ? '000000' : '666666' },
  '000000',
;

$align .= 'clrl';

my @cell_style = map $cell_style_sub, (1..scalar(@header));

push @links,         '', '', $edit_link,    '';
push @link_onclicks, '', '', $edit_onclick, '';

</%init>
