<%doc>

    Bulk package Edit Page

</%doc>
<& /elements/header-cust_main.html,
    view              => 'packages',
    cust_main         => $cust_main,
    include_selectize => 1,
&>
<% include('/elements/error.html') %>

<script>

  let locationnum = "<% $cust_main->ship_locationnum %>";

  function location_changed(e) {
    locationnum = $(e).val();
    $('tr[data-locationnum]').find('input').prop('checked', false);
    $('tr[data-locationnum]').each( function() {
      let tr_el = $(this);
      tr_el.css(
        'display',
        locationnum == tr_el.data('locationnum') ? 'table-row' : 'none'
      );
    });
  }

  function pkg_class_filter_onchange( selected ) {
    if ( selected.length == 0 ) {
      $('tr[data-classnum]').css('display', 'table-row');
    } else {
      $('tr[data-classnum]').each( function() {
        let tr_el = $(this);
        let classnum = tr_el.data('classnum');
        let is_displayed = $.grep( selected, function( item ) {
          return item == classnum;
        });
        let display = is_displayed.length ? 'table-row' : 'none';
        tr_el.css( 'display', is_displayed.length ? 'table-row' : 'none' );
      });
    }
  }

  function confirm_form() {
    let cust_pkg_removed = [];
    let pkg_part_added   = [];

    $('input[data-locationnum]:checked').each( function() {
      let this_el = $(this);
      cust_pkg_removed.push(
        '#' + this_el.data('pkgnum') + ' ' + this_el.data('pkg')
      );
    });

    $('input[data-pkgpart]').each( function() {
      qty_el = $(this);
      qty = qty_el.val();

      if ( qty < 1 ) { return; }

      pkg_part_added.push( qty + ' x ' + qty_el.data('pkg') );
    });

    if ( cust_pkg_removed.length == 0 ) {
      cust_pkg_removed.push('No Existing Packages Selected');
    }
    if ( pkg_part_added.length == 0 ) {
      pkg_part_added.push('No New Packages Selected');
    }

    console.log( cust_pkg_removed );
    console.log( pkg_part_added );

    confirm_html =
      '<div style="margin: 1em;">'
      + '<b><u>Removed Packages:</u></b><br>'
      + cust_pkg_removed.join('<br>')
      + '<br><br>'
      + '<b><u>Replacement Packages:</u></b><br>'
      + pkg_part_added.join('<br>')
      + '<br><br>'
      + '<input type="button" role="button" onclick="submit_form();" value="Confirm Order">'
      + '</div>';

      overlib(
        confirm_html,
        CAPTION, 'Confirm bulk change',
        STICKY,
        AUTOSTATUSCAP,
        MIDX, 0,
        MIDY, 0,
        WIDTH, 300,
        HEIGHT, 200,
        TEXTSIZE, 3,
        BGCOLOR, '#ff0000',
        CGCOLOR, '#ff0000'
      );
  }

  function submit_form() {
    $('#formBulkEdit').submit();
  }
</script>

<form action="<% $fsurl %>edit/process/cust_pkg.cgi" method="POST" id="formBulkEdit">
<input type="hidden" name="custnum" value="<% $custnum %>">
<input type="hidden" name="action" value="bulk">

<p style="margin-bottom: 2em;">
  <label for="locationnum">Service Location</label>
  <% include( '/elements/select-cust_location.html',
      cust_main => $cust_main,
      addnew    => 0,
      onchange  => 'javascript:location_changed(this);',
  ) %><br>
  <span style="font-size: .8em; padding-left: 1em;">
    Bulk-edit works with one customer location at a time
  </span>
</p>

<table style="margin-bottom: 2em;">
  <thead>
    <tr style="background-color: #ccc;">
      <th colspan="2" style="text-align: left;">
        Pkg #
      </th>
      <th style="text-align: left;">
        Current Packages<br>
        <div style="font-size: .8em; padding-left: 1em; font-weight: normal;">
          Selected packages are removed.<br>
          Attached services are moved to the new package selected below
        </span>
      </th>
    </tr>
  </thead>
  <tbody>
%   for my $cust_pkg ( @cust_pkg ) {
%     my $id = sprintf 'remove_cust_pkg[%s]', $cust_pkg->pkgnum;
%     my $is_displayed = $cust_main->ship_locationnum == $cust_pkg->locationnum ? 1 : 0;
      <tr data-locationnum="<% $cust_pkg->locationnum %>" data-pkg="<% $cust_pkg->pkg |h %>" style="display: <% $is_displayed ? 'table-row' : 'none' %>;">
        <td>
          <input type="checkbox"
                 name="<% $id %>"
                 id="<% $id %>"
                 data-pkgnum="<% $cust_pkg->pkgnum %>"
                 data-locationnum="<% $cust_pkg->locationnum %>"
                 data-pkg="<% $part_pkg{ $cust_pkg->pkgpart }->pkg |h %>">
        </td>
        <td>#<% $cust_pkg->pkgnum %></td>
        <td>
          <label for="<% $id %>">
            <% $part_pkg{ $cust_pkg->pkgpart }->pkg %><br>
%           for my $cust_pkg_supp ( @{ $cust_pkg_supp_of{ $cust_pkg->pkgnum }} ) {
              <span style="font-size: .8em; padding-left: 1em;">
                <b>Supplementary:</b> <% $part_pkg{ $cust_pkg_supp->pkgpart }->pkg %>
              </span>
            </label>
%         }
        </td>
      </tr>
%   }
  </tbody>
</table>

<table style="margin-bottom: 2em;">
  <thead>
    <tr style="background-color: #ccc;">
      <th colspan="3">
        <% include('/elements/selectize/select-multiple-pkg_class.html',
            id       => 'filter_pkg_class',
            onchange => 'pkg_class_filter_onchange',
        ) %>
      </th>
    </tr>
    <tr style="background-color: #ccc;">
      <th>Qty</th>
      <th>Class</th>
      <th style="text-align: left;">Order New Packages</th>
    </tr>
  </thead>
  <tbody>
%   for my $part_pkg ( @part_pkg_enabled ) {
%     my $id = sprintf 'qty_part_pkg[%s]', $part_pkg->pkgpart;
      <tr data-classnum="<% $part_pkg->classnum %>">
        <td>
          <input type="text"
                 name="<% $id %>"
                 id="<% $id %>"
                 value="0"
                 size="2"
                 data-pkgpart="<% $part_pkg->pkgpart %>"
                 data-pkg="<% $part_pkg->pkg %>">
          </td>
        <td><% $part_pkg->classname || '(none)' %></td>
        <td><% $part_pkg->pkg %></td>
      </tr>
%   }
  </tbody>
</table>

<input type="button" role="button" value="Order" onclick="confirm_form();">

</form>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

my $custnum = $cgi->param('keywords') || $cgi->param('custnum');
$custnum =~ /^\d+$/
  or die "Invalid custnum($custnum)";

my $cust_main = qsearchs( cust_main => { custnum => $custnum })
  or die "Invalid custnum ($custnum)";

my %part_pkg;
my @part_pkg_enabled;

for my $part_pkg ( qsearch( part_pkg => {} )) {
  $part_pkg{ $part_pkg->pkgpart } = $part_pkg;
  push @part_pkg_enabled, $part_pkg
    unless $part_pkg->disabled;
}
@part_pkg_enabled =
  sort { $a->classname cmp $b->classname || $a->pkg cmp $b->pkg }
  @part_pkg_enabled;

my @cust_pkg;
my %cust_pkg_supp_of;
for my $cust_pkg (
  qsearch(
    cust_pkg => {
      custnum  => $custnum,
      cancel   => '',
    }
  )
) {
  if ( my $main_pkgnum = $cust_pkg->main_pkgnum ) {
    $cust_pkg_supp_of{ $main_pkgnum } //= [];
    push @{ $cust_pkg_supp_of{ $main_pkgnum } }, $cust_pkg;
  } else {
    $cust_pkg_supp_of{ $cust_pkg->pkgnum } //= [];
    push @cust_pkg, $cust_pkg;
  }
}
</%init>
