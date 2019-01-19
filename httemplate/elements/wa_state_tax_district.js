<%doc>

Provide js function in support of a lookup hook for wa_state_tax_districts

wa_state_tax_district()
* Checks form_address_info() to collect address data
* If any addresses are in Washington State,
* Uses misc/xmlhttp-wa_state-find_district_for_address.html to query
  wa state tax districting database
* Displays error, or updates the district input element for the addresses
* Calls submit_continue() upon success
* Calls submit_abort() upon error

</%doc>

function wa_state_tax_district() {
  // Queries the WA State API to get a Tax District for this address
  // upon failure: User can choose to skip or cancel
  // upon success: set value of district input box and submit_continue()

  address_info = form_address_info();
  // console.log( address_info );

  if (
       address_info['state'] != 'WA'
    && address_info['state'] != 'wa'
    && address_info['bill_state'] != 'WA'
    && address_info['bill_state'] != 'wa'
    && (
      address_info['same']
      || (
        address_info['ship_state'] != 'WA'
        && address_info['ship_state'] != 'wa'
      )
    )
  ) {
    // nothing to do, not in Washington state
    submit_continue();
    return;
  }

  wa_state_tax_district_overlib( 'Looking up tax district... please wait...' );

  $.post({
    url: "<% $fsurl %>misc/xmlhttp-wa_state-find_district_for_address.html",
    data: address_info,
    success: function(response) {
      // console.log(response);

      let error = '';
      if ( response['error'] ) {
        error = error + response['error'] + ' ';
      }

      // populate Billing Address district into form, or record error
      if ( response['bill'] && response['bill']['district'] ) {
        $('#bill_district').val( response['bill']['district'] );
      }
      else if ( response['bill'] && response['bill']['error'] ) {
        error = error + 'Cound not set tax district for billing address. ';
      }

      // populate Shipping Address district into form, or record error
      if (
        ! address_info['same']
        && response['ship']
        && response['ship']['district']
      ) {
        $('#ship_district').val( response['ship']['district'] );
      }
      else if (
        ! address_info['same']
        && response['ship']
        && response['ship']['error']
      ) {
        error = error + 'Could not set tax district for service address. ';
      }

      // populate Plain Address district into form, or record error
      if (
        response['address']
        && response['address']['district']
      ) {
        $('#district').val( response['address']['district'] );
      }
      else if (
        response['address']
        && response['address']['error']
      ) {
        error = error + 'Could not set tax district for address. ';
      }

      if ( error ) {
        wa_state_tax_district_overlib(
          'An error occured determining Washington state tax district:<br>'
          + '<br>'
          + error + '<br>'
          + '<br>'
          + 'If you choose to skip this step, taxes will not be calculated '
          + 'for this customer, unless you enter a tax district manually.'
          + '<br>'
          + '<a href="https://webgis.dor.wa.gov/taxratelookup/SalesTax.aspx" target="_blank">See WA Dept of Revenue</a>'
        );
      }
      else {
        cClick();
        submit_continue();
        return;
      }

    }
  })
  .fail(function() {
    wa_state_tax_district_overlib(
      'A network error occured determining Washington state tax district:<br>'
      + '<br>'
      + 'If you choose to skip this step, taxes will not be calculated '
      + 'for this customer, unless you enter a tax district manually.'
      + '<br>'
      + '<a href="https://webgis.dor.wa.gov/taxratelookup/SalesTax.aspx" target="_blank">See WA Dept of Revenue</a>'
    );
  });
}

function wa_state_tax_district_overlib(html) {
  html =
      '<div style="text-align: center;">'
    +   '<h2>Washington State Tax District Lookup</h2>'
    +   '<p>' + html + '</p>'
    + '<a href="#" onclick="wa_state_tax_district_skip()">skip</a>'
    + ' | '
    + '<a href="#" onclick="wa_state_tax_district_cancel()">cancel</a>'
    + '</div>';

  overlib(
    html,
    CAPTION, 'WA State Tax District',
    STICKY,
    CLOSETEXT, '',
    MIDX, 0,
    MIDY, 0,
    WIDTH, 500,
    BGCOLOR, '#339',
    CGCOLOR, '#339',
    TEXTSIZE, 3
  );
}

function wa_state_tax_district_skip() {
  // Click target to skip tax district determination
  cClick()
  submit_continue();
}

function wa_state_tax_district_cancel() {
  // Click target to cancel submit from tax district determination
  cClick()
  submit_abort();
}
