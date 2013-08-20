function pkg_changed () {
  var form = document.OrderPkgForm;
  var discountnum = form.discountnum;

  if ( form.pkgpart.selectedIndex > 0 ) {

    var opt = form.pkgpart.options[form.pkgpart.selectedIndex];
    var date_button = document.getElementById('start_date_button');
    var date_button_disabled = document.getElementById('start_date_button_disabled');
    var date_text = document.getElementById('start_date_text');


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
    } else {
      date_text.style.backgroundColor = '#dddddd';
      date_text.disabled = true;
      date_button.style.display = 'none';
      date_button_disabled.style.display = '';
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
