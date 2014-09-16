function pkg_changed () {
  var form = document.OrderPkgForm;
  var discountnum = form.discountnum;

  if ( form.pkgpart.selectedIndex > 0 ) {

    var opt = form.pkgpart.options[form.pkgpart.selectedIndex];
    var date_button = document.getElementById('start_date_button');
    var date_button_disabled = document.getElementById('start_date_disabled');
    var date_text = document.getElementById('start_date_text');

    var radio_now = document.getElementById('start_now');
    var radio_on_hold = document.getElementById('start_on_hold');
    var radio_on_date = document.getElementById('start_on_date');

    form.submitButton.disabled = false;
    if ( discountnum ) {
      if ( opt.getAttribute('data-can_discount') == 1 ) {
        form.discountnum.disabled = false;
        discountnum_changed(form.discountnum);
      } else {
        form.discountnum.disabled = true;
        discountnum_changed(form.discountnum);
      }
    }

    // if this form element exists, then the start date is a future
    // package change date; don't replace it
    if ( form.delay ) {
      return;
    }
    form.start_date_text.value = opt.getAttribute('data-start_date');
    if ( opt.getAttribute('data-can_start_date') == 1 ) {
      date_text.style.backgroundColor = '#ffffff';
      date_text.disabled = false;
      date_button.style.display = '';
      date_button_disabled.style.display = 'none';
      if ( radio_on_date ) {
        // un-disable all the buttons that might get disabled
        radio_on_date.disabled = false;
        radio_now.disabled = false;
        // if a start date has been entered, assume the user wants it
        if ( form.start_date_text.value.length > 0 ) {
          radio_now.checked = false;
          radio_on_date.checked = true;
        } else {
          // if not, default to now
          radio_now.checked = true;
        }
      }
    } else { // the package is either fixed start date or start-on-hold
      date_text.style.backgroundColor = '#dddddd';
      date_text.disabled = true;
      date_button.style.display = 'none';
      date_button_disabled.style.display = '';
      if ( radio_on_date ) {
        if ( opt.getAttribute('data-start_on_hold') == 1 ) {
          // disallow all options but "On hold"
          radio_on_hold.checked = true;
          radio_now.checked = false;
          radio_now.disabled = true;
        } else {
          // disallow all options but "On date"
          radio_on_hold.checked = false;
          radio_now.checked = true;
          radio_now.disabled = false;
        }
      }
    }

    get_part_pkg_usageprice( opt.value, update_part_pkg_usageprice );

  } else {
    form.submitButton.disabled = true;
    if ( discountnum ) { form.discountnum.disabled = true; }
    discountnum_changed(form.discountnum);
  }
}

function update_part_pkg_usageprice(part_pkg_usageprice) {

  var table = document.getElementById('cust_pkg_usageprice_table');

  // black the current usage price rows
  for ( var r = table.rows.length - 1; r >= 0; r-- ) {
    table.deleteRow(r);
  }

  // add the new usage price rows
  var rownum = 0;
  var usagepriceArray = eval('(' + part_pkg_usageprice + ')' );
  for ( var s = 0; s < usagepriceArray.length; s=s+2 ) {
    //surely this should be some kind of JSON structure
    var html       = usagepriceArray[s+0];
    var javascript = usagepriceArray[s+1];

    // a lot like ("inspiried by") edit/elements/edit.html function spawn_<%$field%>

    // XXX evaluate the javascript
    //if (window.ActiveXObject) {
    //  window.execScript(newfunc);
    //} else { /* (window.XMLHttpRequest) */
    //  //window.eval(newfunc);
    //  setTimeout(newfunc, 0);
    //}

    var row = table.insertRow(rownum++);

    //var label_cell = document.createElement('TD');

    //label_cell.id = '<% $field %>_label' + <%$field%>_fieldnum;

    //label_cell.style.textAlign = "right";
    //label_cell.style.verticalAlign = "top";
    //label_cell.style.borderTop = "1px solid black";
    //label_cell.style.paddingTop = "5px";

    //label_cell.innerHTML = '<% $label %>';

    //row.appendChild(label_cell);
          
    var widget_cell = document.createElement('TD');

    //widget_cell.style.borderTop = "1px solid black";
    widget_cell.style.paddingTop = "3px";
    widget_cell.colSpan = "2";

    widget_cell.innerHTML = html;

    row.appendChild(widget_cell);

  }

  if ( rownum > 0 ) {
    document.getElementById('cust_pkg_usageprice_title').style.display = '';
  } else {
    document.getElementById('cust_pkg_usageprice_title').style.display = 'none';
  }

}


function standardize_new_location() {
  var form = document.OrderPkgForm;
  var loc = form.locationnum;
  if (loc.type == 'select-one' && loc.options[loc.selectedIndex].value == -1){
    standardize_locations();
  } else {
    form.submit();
  }
}

function submit_abort() {
  document.OrderPkgForm.submitButton.disabled = false;
  nd(1);
}
