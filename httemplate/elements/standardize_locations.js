function form_address_info() {
  var cf = document.<% $formname %>;
  var state_el      = cf.elements['<% $main_prefix %>state'];
  var ship_state_el = cf.elements['<% $ship_prefix %>state'];
  return {
% if ( $onlyship ) {
    'onlyship': 1,
% } else {
%   if ( $withfirm ) {
    'company',  cf.elements['company'].value,
%   }
    'address1': cf.elements['<% $main_prefix %>address1'].value,
    'address2': cf.elements['<% $main_prefix %>address2'].value,
    'city':     cf.elements['<% $main_prefix %>city'].value,
    'state':    state_el.options[ state_el.selectedIndex ].value,
    'zip':      cf.elements['<% $main_prefix %>zip'].value,
    'country':  cf.elements['<% $main_prefix %>country'].value,
% }
% if ( $withcensus ) {
    'ship_censustract': cf.elements['enter_censustract'].value,
% }
    'ship_address1': cf.elements['<% $ship_prefix %>address1'].value,
    'ship_address2': cf.elements['<% $ship_prefix %>address2'].value,
    'ship_city':     cf.elements['<% $ship_prefix %>city'].value,
    'ship_state':    ship_state_el.options[ ship_state_el.selectedIndex ].value,
    'ship_zip':      cf.elements['<% $ship_prefix %>zip'].value,
    'ship_country':  cf.elements['<% $ship_prefix %>country'].value,
  };
}

function standardize_locations() {

  var startup_msg = '<P STYLE="position:absolute; top:50%; margin-top:-1em; width:100%; text-align:center"><B><FONT SIZE="+1">Verifying address...</FONT></B></P>';
  overlib(startup_msg, WIDTH, 444, HEIGHT, 168, CAPTION, 'Please wait...', STICKY, AUTOSTATUSCAP, CLOSECLICK, MIDX, 0, MIDY, 0);
  var cf = document.<% $formname %>;
  var address_info = form_address_info();

  var changed = false; // have any of the address fields been changed?

// clear coord_auto fields if the user has changed the coordinates
% for my $pre ($ship_prefix, $onlyship ? () : $main_prefix) {
%   for my $field ($pre.'latitude', $pre.'longitude') {

  if ( cf.elements['<% $field %>'].value != cf.elements['old_<% $field %>'].value ) {
    cf.elements['<% $pre %>coord_auto'].value = '';
  }

%   }
  // but if the coordinates have been set to null, turn coord_auto on 
  // and standardize
  if ( cf.elements['<% $pre %>latitude'].value == '' &&
       cf.elements['<% $pre %>longitude'].value == '' ) {
    cf.elements['<% $pre %>coord_auto'].value = 'Y';
    changed = true;
  }

% }

  // standardize if the old address wasn't clean
  if ( cf.elements['old_<% $ship_prefix %>addr_clean'].value == '' ||
      ( <% !$onlyship || 0 %> && 
        cf.elements['old_<% $main_prefix %>addr_clean'].value == '' ) ) {

    changed = true;

  }
  // or if it was clean but has been changed
  for (var key in address_info) {
    var old_el = cf.elements['old_'+key];
    if ( old_el && address_info[key] != old_el.value ) {
      changed = true;
      break;
    }
  }

% # If address hasn't been changed, auto-confirm the existing value of 
% # censustract so that we don't ask the user to confirm it again.

  if ( !changed ) {
    cf.elements['<% $main_prefix %>censustract'].value =
      address_info['ship_censustract'];
  }

% if ( $conf->config('address_standardize_method') ) {
  if ( changed ) {
    address_standardize(JSON.stringify(address_info), confirm_standardize);
  }
  else {
    cf.elements['ship_addr_clean'].value = 'Y';
%   if ( !$onlyship ) {
    cf.elements['addr_clean'].value = 'Y';
%   }
    post_standardization();
  }

% } else {

  post_standardization();

% } # if address_standardize_method
}

var returned;

function confirm_standardize(arg) {
  // contains 'old', which was what we sent, and 'new', which is what came
  // back, including any errors
  returned = JSON.parse(arg);

  if ( <% $conf->exists('cust_main-auto_standardize_address') || 0 %> ) {

    replace_address(); // with the contents of returned['new']
  
  }
  else {

    var querystring = encodeURIComponent( JSON.stringify(returned) );
    // confirmation popup: knows to call replace_address(), 
    // post_standardization(), or submit_abort() depending on the 
    // user's choice.
    OLpostAJAX(
        '<%$p%>/misc/confirm-address_standardize.html', 
        'q='+querystring,
        function() {
          overlib( OLresponseAJAX, CAPTION, 'Address standardization', STICKY, 
            AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 
            576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399', 
            TEXTSIZE, 3 );
        }, 0);

  }
}

function replace_address() {

  var newaddr = returned['new'];

  var clean = newaddr['addr_clean'] == 'Y';
  var ship_clean = newaddr['ship_addr_clean'] == 'Y';
  var error = newaddr['error'];
  var ship_error = newaddr['ship_error'];

  var cf = document.<% $formname %>;
  var state_el      = cf.elements['<% $main_prefix %>state'];
  var ship_state_el = cf.elements['<% $ship_prefix %>state'];

% if ( !$onlyship ) {
  if ( clean ) {
%   if ( $withfirm ) {
        cf.elements['<% $main_prefix %>company'].value  = newaddr['company'];
%   }
        cf.elements['<% $main_prefix %>address1'].value = newaddr['address1'];
        cf.elements['<% $main_prefix %>address2'].value = newaddr['address2'];
        cf.elements['<% $main_prefix %>city'].value     = newaddr['city'];
        setselect(cf.elements['<% $main_prefix %>state'], newaddr['state']);
        cf.elements['<% $main_prefix %>zip'].value      = newaddr['zip'];
        cf.elements['<% $main_prefix %>addr_clean'].value = 'Y';

        if ( cf.elements['<% $main_prefix %>coord_auto'].value ) {
          cf.elements['<% $main_prefix %>latitude'].value = newaddr['latitude'];
          cf.elements['<% $main_prefix %>longitude'].value = newaddr['longitude'];
        }
  }
% }

  if ( ship_clean ) {
% if ( $withfirm ) {
      cf.elements['<% $ship_prefix %>company'].value  = newaddr['ship_company'];
% }
      cf.elements['<% $ship_prefix %>address1'].value = newaddr['ship_address1'];
      cf.elements['<% $ship_prefix %>address2'].value = newaddr['ship_address2'];
      cf.elements['<% $ship_prefix %>city'].value     = newaddr['ship_city'];
      setselect(cf.elements['<% $ship_prefix %>state'], newaddr['ship_state']);
      cf.elements['<% $ship_prefix %>zip'].value      = newaddr['ship_zip'];
      cf.elements['<% $ship_prefix %>addr_clean'].value = 'Y';
      if ( cf.elements['<% $ship_prefix %>coord_auto'].value ) {
        cf.elements['<% $ship_prefix %>latitude'].value = newaddr['latitude'];
        cf.elements['<% $ship_prefix %>longitude'].value = newaddr['longitude'];
      }
  }
% if ( $withcensus ) {
% # then set the censustract if address_standardize provided one.
  if ( ship_clean && newaddr['ship_censustract'] ) {
      cf.elements['<% $main_prefix %>censustract'].value = newaddr['ship_censustract'];
  }
% }

  post_standardization();

}

function confirm_manual_address() {
%# not much to do in this case, just confirm the censustract
% if ( $withcensus ) {
  var cf = document.<% $formname %>;
  cf.elements['<% $main_prefix %>censustract'].value =
  cf.elements['<% $main_prefix %>enter_censustract'].value;
% }
  post_standardization();
}

function post_standardization() {

% if ( $conf->exists('enable_taxproducts') ) {

  if ( new String(cf.elements['<% $taxpre %>zip'].value).length < 10 )
  {

    var country_el = cf.elements['<% $taxpre %>country'];
    var country = country_el.options[ country_el.selectedIndex ].value;
    var geocode = cf.elements['geocode'].value;

    if ( country == 'CA' || country == 'US' ) {

      var state_el = cf.elements['<% $taxpre %>state'];
      var state = state_el.options[ state_el.selectedIndex ].value;

      var url = "<% $p %>/misc/choose_tax_location.html" +
                  "?data_vendor=cch-zip" + 
                  ";city="     + cf.elements['<% $taxpre %>city'].value +
                  ";state="    + state + 
                  ";zip="      + cf.elements['<% $taxpre %>zip'].value +
                  ";country="  + country +
                  ";geocode="  + geocode +
                  ";formname=" + '<% $formname %>' +
                  ";";

      // popup a chooser
      OLgetAJAX( url, update_geocode, 300 );

    } else {

      cf.elements['geocode'].value = 'DEFAULT';
      <% $post_geocode %>;

    }

  } else {

    cf.elements['geocode'].value = '';
    <% $post_geocode %>;

  }

% } else {

  <% $post_geocode %>;

% }

}

function update_geocode() {

  //yay closures
  set_geocode = function (what) {

    var cf = document.<% $formname %>;

    //alert(what.options[what.selectedIndex].value);
    var argsHash = eval('(' + what.options[what.selectedIndex].value + ')');
    cf.elements['<% $taxpre %>city'].value     = argsHash['city'];
    setselect(cf.elements['<% $taxpre %>state'], argsHash['state']);
    cf.elements['<% $taxpre %>zip'].value      = argsHash['zip'];
    cf.elements['geocode'].value  = argsHash['geocode'];
    <% $post_geocode %>;

  }

  // popup a chooser

  overlib( OLresponseAJAX, CAPTION, 'Select tax location', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

}

function setselect(el, value) {

  for ( var s = 0; s < el.options.length; s++ ) {
     if ( el.options[s].value == value ) {
       el.selectedIndex = s;
     }
  }

}
<%init>

my %opt = @_;
my $conf = new FS::Conf;

my $withfirm = 1;
my $withcensus = 1;

my $formname =  $opt{form} || 'CustomerForm';
my $onlyship =  $opt{onlyship} || '';
my $main_prefix =  $opt{main_prefix} || '';
my $ship_prefix =  $opt{ship_prefix} || ($onlyship ? '' : 'ship_');
my $taxpre = $main_prefix;
$taxpre = $ship_prefix if ( $conf->exists('tax-ship_address') || $onlyship );
my $post_geocode = $opt{callback} || 'post_geocode();';
$withfirm = 0 if $opt{no_company};
$withcensus = 0 if $opt{no_census};

</%init>
