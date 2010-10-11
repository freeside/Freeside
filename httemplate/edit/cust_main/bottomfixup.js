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
