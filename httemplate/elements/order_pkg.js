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

  } else {
    form.submitButton.disabled = true;
    if ( discountnum ) { form.discountnum.disabled = true; }
    discountnum_changed(form.discountnum);
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
