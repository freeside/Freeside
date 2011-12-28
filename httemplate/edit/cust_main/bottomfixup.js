function bottomfixup(what) {

%# ../cust_main.cgi
  var layervars = new Array(
    'payauto', 'billday',
    'payinfo', 'payinfo1', 'payinfo2', 'payinfo3', 'paytype',
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
  standardize_locations();

}

<% include( '/elements/standardize_locations.js',
            'callback', 'post_geocode();'
          )
%>

function post_geocode() {

% if ( $conf->exists('cust_main-require_censustract') ) {

  //alert('fetch census tract data');
  var cf = document.CustomerForm;
  var state_el = cf.elements['ship_state'];
  var census_data = new Array(
    'year',   <% $conf->config('census_year') || '2011' %>,
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

<%init>

my $conf = new FS::Conf;

</%init>
