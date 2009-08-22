function bottomfixup(what) {

%# ../cust_main.cgi
  var layervars = new Array(
    'payauto',
    'payinfo', 'payinfo1', 'payinfo2', 'paytype',
    'payname', 'paystate', 'exp_month', 'exp_year', 'paycvv',
    'paystart_month', 'paystart_year', 'payissue',
    'payip',
    'paid'
  );

  var cf = document.CustomerForm;
  var payby = cf.payby.options[cf.payby.selectedIndex].value;
  for ( f=0; f < layervars.length; f++ ) {
    var field = layervars[f];
    copyelement( cf.elements[payby + '_' + field],
                 cf.elements[field]
               );
  }

  //this part does USPS address correction

  // XXX should this be first and should we update the form fields that are
  // displayed???

  var cf = document.CustomerForm;

  var state_el      = cf.elements['state'];
  var ship_state_el = cf.elements['ship_state'];

  //address_standardize(
  var cust_main = new Array(
    'company',  cf.elements['company'].value,
    'address1', cf.elements['address1'].value,
    'address2', cf.elements['address2'].value,
    'city',     cf.elements['city'].value,
    'state',    state_el.options[ state_el.selectedIndex ].value,
    'zip',      cf.elements['zip'].value,

    'ship_company',  cf.elements['ship_company'].value,
    'ship_address1', cf.elements['ship_address1'].value,
    'ship_address2', cf.elements['ship_address2'].value,
    'ship_city',     cf.elements['ship_city'].value,
    'ship_state',    ship_state_el.options[ ship_state_el.selectedIndex ].value,
    'ship_zip',      cf.elements['ship_zip'].value
  );

  address_standardize( cust_main, update_address );

}

var standardize_address;

function update_address(arg) {

  var argsHash = eval('(' + arg + ')');

  var changed  = argsHash['address_standardized'];
  var ship_changed = argsHash['ship_address_standardized'];
  var error = argsHash['error'];
  var ship_error = argsHash['ship_error'];
  

  //yay closures
  standardize_address = function () {

    var cf = document.CustomerForm;
    var state_el      = cf.elements['state'];
    var ship_state_el = cf.elements['ship_state'];

    if ( changed ) {
      cf.elements['company'].value  = argsHash['new_company'];
      cf.elements['address1'].value = argsHash['new_address1'];
      cf.elements['address2'].value = argsHash['new_address2'];
      cf.elements['city'].value     = argsHash['new_city'];
      setselect(cf.elements['state'], argsHash['new_state']);
      cf.elements['zip'].value      = argsHash['new_zip'];
    }

    if ( ship_changed ) {
      cf.elements['ship_company'].value  = argsHash['new_ship_company'];
      cf.elements['ship_address1'].value = argsHash['new_ship_address1'];
      cf.elements['ship_address2'].value = argsHash['new_ship_address2'];
      cf.elements['ship_city'].value     = argsHash['new_ship_city'];
      setselect(cf.elements['ship_state'], argsHash['new_ship_state']);
      cf.elements['ship_zip'].value      = argsHash['new_ship_zip'];
    }

    post_standardization();

  }



  if ( changed || ship_changed ) {

%   if ( $conf->exists('cust_main-auto_standardize_address') ) {

    standardize_address();

%   } else {

    // popup a confirmation popup

    var confirm_change =
      '<CENTER><BR><B>Confirm address standardization</B><BR><BR>' +
      '<TABLE>';
    
    if ( changed ) {

      confirm_change = confirm_change + 
        '<TR><TH>Entered billing address</TH>' +
          '<TH>Standardized billing address</TH></TR>';
        // + '<TR><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>';
      
      if ( argsHash['company'] || argsHash['new_company'] ) {
        confirm_change = confirm_change +
        '<TR><TD>' + argsHash['company'] +
          '</TD><TD>' + argsHash['new_company'] + '</TD></TR>';
      }
      
      confirm_change = confirm_change +
        '<TR><TD>' + argsHash['address1'] +
          '</TD><TD>' + argsHash['new_address1'] + '</TD></TR>' +
        '<TR><TD>' + argsHash['address2'] +
          '</TD><TD>' + argsHash['new_address2'] + '</TD></TR>' +
        '<TR><TD>' + argsHash['city'] + ', ' + argsHash['state'] + '  ' + argsHash['zip'] +
          '</TD><TD>' + argsHash['new_city'] + ', ' + argsHash['new_state'] + '  ' + argsHash['new_zip'] + '</TD></TR>' +
          '<TR><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>';

    }

    if ( ship_changed ) {

      confirm_change = confirm_change + 
        '<TR><TH>Entered service address</TH>' +
          '<TH>Standardized service address</TH></TR>';
        // + '<TR><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>';
      
      if ( argsHash['ship_company'] || argsHash['new_ship_company'] ) {
        confirm_change = confirm_change +
        '<TR><TD>' + argsHash['ship_company'] +
          '</TD><TD>' + argsHash['new_ship_company'] + '</TD></TR>';
      }
      
      confirm_change = confirm_change +
        '<TR><TD>' + argsHash['ship_address1'] +
          '</TD><TD>' + argsHash['new_ship_address1'] + '</TD></TR>' +
        '<TR><TD>' + argsHash['ship_address2'] +
          '</TD><TD>' + argsHash['new_ship_address2'] + '</TD></TR>' +
        '<TR><TD>' + argsHash['ship_city'] + ', ' + argsHash['ship_state'] + '  ' + argsHash['ship_zip'] +
          '</TD><TD>' + argsHash['new_ship_city'] + ', ' + argsHash['new_ship_state'] + '  ' + argsHash['new_ship_zip'] + '</TD></TR>' +
        '<TR><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>';

    }

    var addresses = 'address';
    var height = 268;
    if ( changed && ship_changed ) {
      addresses = 'addresses';
      height = 396; // #what
    }

    confirm_change = confirm_change +
      '<TR><TD>' +
        '<BUTTON TYPE="button" onClick="post_standardization();"><IMG SRC="<%$p%>images/error.png" ALT=""> Use entered ' + addresses + '</BUTTON>' + 
      '</TD><TD>' +
        '<BUTTON TYPE="button" onClick="standardize_address();"><IMG SRC="<%$p%>images/tick.png" ALT=""> Use standardized ' + addresses + '</BUTTON>' + 
      '</TD></TR>' +
      '<TR><TD COLSPAN=2 ALIGN="center">' +
        '<BUTTON TYPE="button" onClick="document.CustomerForm.submitButton.disabled=false; parent.cClick();"><IMG SRC="<%$p%>images/cross.png" ALT=""> Cancel submission</BUTTON></TD></TR>' +
        
      '</TABLE></CENTER>';

    overlib( confirm_change, CAPTION, 'Confirm address standardization', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, height, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

%   }

  } else {

    post_standardization();

  }


}

function post_standardization() {

  var cf = document.CustomerForm;

% if ( $conf->exists('enable_taxproducts') ) {

  if ( new String(cf.elements['<% $taxpre %>zip'].value).length < 10 )
  {

    var country_el = cf.elements['<% $taxpre %>country'];
    var country = country_el.options[ country_el.selectedIndex ].value;

    if ( country == 'CA' || country == 'US' ) {

      var state_el = cf.elements['<% $taxpre %>state'];
      var state = state_el.options[ state_el.selectedIndex ].value;

      var url = "cust_main/choose_tax_location.html" +
                  "?data_vendor=cch-zip" + 
                  ";city="    + cf.elements['<% $taxpre %>city'].value +
                  ";state="   + state + 
                  ";zip="     + cf.elements['<% $taxpre %>zip'].value +
                  ";country=" + country +
                  ";";

      // popup a chooser
      OLgetAJAX( url, update_geocode, 300 );

    } else {

      cf.elements['geocode'].value = 'DEFAULT';
      post_geocode();

    }

  } else {

    post_geocode();

  }

% } else {

  post_geocode();

% }

}

function post_geocode() {

% if ( $conf->exists('cust_main-require_censustract') ) {

  //alert('fetch census tract data');
  var cf = document.CustomerForm;
  var state_el = cf.elements['ship_state'];
  var census_data = new Array(
    'year',   <% $conf->config('census_year') || '2009' %>,
    'address', cf.elements['ship_address1'].value,
    'city',    cf.elements['ship_city'].value,
    'state',   state_el.options[ state_el.selectedIndex ].value,
    'zip',     cf.elements['ship_zip'].value
  );

  censustract( census_data, update_censustract );

% }else{

  document.CustomerForm.submit();

% }

}

function update_geocode() {

  //yay closures
  set_geocode = function (what) {

    var cf = document.CustomerForm;

    //alert(what.options[what.selectedIndex].value);
    var argsHash = eval('(' + what.options[what.selectedIndex].value + ')');
    cf.elements['<% $taxpre %>city'].value     = argsHash['city'];
    setselect(cf.elements['<% $taxpre %>state'], argsHash['state']);
    cf.elements['<% $taxpre %>zip'].value      = argsHash['zip'];
    cf.elements['geocode'].value  = argsHash['geocode'];
    post_geocode();

  }

  // popup a chooser

  overlib( OLresponseAJAX, CAPTION, 'Select tax location', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

}

var set_censustract;

function update_censustract(arg) {

  var argsHash = eval('(' + arg + ')');

  var cf = document.CustomerForm;

  var msacode    = argsHash['msacode'];
  var statecode  = argsHash['statecode'];
  var countycode = argsHash['countycode'];
  var tractcode  = argsHash['tractcode'];
  var error      = argsHash['error'];
  
  var newcensus = 
    new String(statecode)  +
    new String(countycode) +
    new String(tractcode).replace(/\s$/, '');  // JSON 1 workaround

  set_censustract = function () {

    cf.elements['censustract'].value = newcensus
    cf.submit();

  }

  if (error || cf.elements['censustract'].value != newcensus) {
    // popup an entry dialog

    if (error) { newcensus = error; }
    newcensus.replace(/.*ndefined.*/, 'Not found');

    var choose_censustract =
      '<CENTER><BR><B>Confirm censustract</B><BR>' +
      '<A href="http://maps.ffiec.gov/FFIECMapper/TGMapSrv.aspx?' +
      'census_year=<% $conf->config('census_year') || '2008' %>' +
      '&latitude=' + cf.elements['latitude'].value +
      '&longitude=' + cf.elements['longitude'].value +
      '" target="_blank">Map service module location</A><BR>' +
      '<A href="http://maps.ffiec.gov/FFIECMapper/TGMapSrv.aspx?' +
      'census_year=<% $conf->config('census_year') || '2008' %>' +
      '&zip_code=' + cf.elements['ship_zip'].value +
      '" target="_blank">Map zip code center</A><BR><BR>' +
      '<TABLE>';
    
    choose_censustract = choose_censustract + 
      '<TR><TH style="width:50%">Entered census tract</TH>' +
        '<TH style="width:50%">Calculated census tract</TH></TR>' +
      '<TR><TD>' + cf.elements['censustract'].value +
        '</TD><TD>' + newcensus + '</TD></TR>' +
        '<TR><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>';

    choose_censustract = choose_censustract +
      '<TR><TD ALIGN="center">' +
        '<BUTTON TYPE="button" onClick="document.CustomerForm.submit();"><IMG SRC="<%$p%>images/error.png" ALT=""> Use entered census tract </BUTTON>' + 
      '</TD><TD ALIGN="center">' +
        '<BUTTON TYPE="button" onClick="set_censustract();"><IMG SRC="<%$p%>images/tick.png" ALT=""> Use calculated census tract </BUTTON>' + 
      '</TD></TR>' +
      '<TR><TD COLSPAN=2 ALIGN="center">' +
        '<BUTTON TYPE="button" onClick="document.CustomerForm.submitButton.disabled=false; parent.cClick();"><IMG SRC="<%$p%>images/cross.png" ALT=""> Cancel submission</BUTTON></TD></TR>' +
        
      '</TABLE></CENTER>';

    overlib( choose_censustract, CAPTION, 'Confirm censustract', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

  } else {

    cf.submit();

  }

}

function copyelement(from, to) {
  if ( from == undefined ) {
    to.value = '';
  } else if ( from.type == 'select-one' ) {
    to.value = from.options[from.selectedIndex].value;
    //alert(from + " (" + from.type + "): " + to.name + " => (" + from.selectedIndex + ") " + to.value);
  } else if ( from.type == 'checkbox' ) {
    if ( from.checked ) {
      to.value = from.value;
    } else {
      to.value = '';
    }
  } else {
    if ( from.value == undefined ) {
      to.value = '';
    } else {
      to.value = from.value;
    }
  }
  //alert(from + " (" + from.type + "): " + to.name + " => " + to.value);
}

function setselect(el, value) {

  for ( var s = 0; s < el.options.length; s++ ) {
     if ( el.options[s].value == value ) {
       el.selectedIndex = s;
     }
  }

}
<%init>

my $conf = new FS::Conf;

my $taxpre = $conf->exists('tax-ship_address') ? 'ship_' : '';

</%init>
