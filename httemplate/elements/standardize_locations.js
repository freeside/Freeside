function status_message(text, caption) {
  text = '<P STYLE="position:absolute; top:50%; margin-top:-1em; width:100%; text-align:center"><B><FONT SIZE="+1">' + text + '</FONT></B></P>';
  caption = caption || 'Please wait...';
  overlib(text, WIDTH, 444, HEIGHT, 168, CAPTION, caption, STICKY, AUTOSTATUSCAP, CLOSECLICK, MIDX, 0, MIDY, 0);
}

function form_address_info() {
  var cf = document.<% $formname %>;

  var returnobj = { billship: <% $billship %> };
% if ( $billship ) {
  returnobj['same'] = cf.elements['same'].checked;
% }
% if ( $withcensus ) {
% # "entered" censustract always goes with the ship_ address if there is one
%   if ( $billship ) {
    returnobj['ship_censustract'] = cf.elements['enter_censustract'].value;
%   } else { # there's only a package address, so it's just "censustract"
    returnobj['censustract'] = cf.elements['enter_censustract'].value;
%   }
% }
% for my $pre (@prefixes) {
  if ( <% $pre eq 'ship_' ? 1 : 0 %> && returnobj['same'] ) {
%   # special case: don't include any ship_ fields, and move the entered
%   # censustract over to bill_.
    returnobj['bill_censustract'] = returnobj['ship_censustract'];
    delete returnobj['ship_censustract'];
  } else {
%   # normal case
%   for my $field (qw(address1 address2 city state zip country)) {
    returnobj['<% $pre %><% $field %>'] = cf.elements['<% $pre %><% $field %>'].value;
%   } #for $field
  } // if returnobj['same']
% } #foreach $pre

  return returnobj;
}

function standardize_locations() {

  var cf = document.<% $formname %>;
  var address_info = form_address_info();

  var changed = false; // have any of the address fields been changed?

// clear coord_auto fields if the user has changed the coordinates
% for my $pre (@prefixes) {
%   for my $field ($pre.'latitude', $pre.'longitude') {

  if ( cf.elements['<% $field %>'].value != cf.elements['old_<% $field %>'].value ) {
    cf.elements['<% $pre %>coord_auto'].value = '';
  }

%   } #foreach $field
  // but if the coordinates have been set to null, turn coord_auto on 
  // and standardize
  if ( cf.elements['<% $pre %>latitude'].value == '' &&
       cf.elements['<% $pre %>longitude'].value == '' ) {
    cf.elements['<% $pre %>coord_auto'].value = 'Y';
    changed = true;
  }
  // standardize if the old address wasn't clean
  if ( cf.elements['<% $pre %>addr_clean'].value == '' ) {
    changed = true;
  }
% } #foreach $pre

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

  if ( !changed && <% $withcensus %> ) {
%   if ( $billship ) {
    if ( address_info['same'] ) {
      cf.elements['bill_censustract'].value =
        address_info['bill_censustract'];
    } else {
      cf.elements['ship_censustract'].value =
        address_info['ship_censustract'];
    }
%   } else {
      cf.elements['censustract'].value =
        address_info['censustract'];
%   }
  }

% if ( $conf->config('address_standardize_method') ) {
  if ( changed ) {
    status_message('Verifying address...');
    address_standardize(JSON.stringify(address_info), confirm_standardize);
  }
  else {
%   foreach my $pre (@prefixes) {
    cf.elements['<% $pre %>addr_clean'].value = 'Y';
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
  
  } else if ( returned['all_same'] ) {

    // then all entered address fields are correct
    // but we still need to set the lat/long fields and addr_clean
    status_message('Verified');
    replace_address();

  } else {

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

  var cf = document.<% $formname %>;
%  foreach my $pre (@prefixes) {
  var clean = newaddr['<% $pre %>addr_clean'] == 'Y';
  var error = newaddr['<% $pre %>error'];
  if ( clean ) {
%   foreach my $field (qw(address1 address2 city state zip addr_clean )) {
    cf.elements['<% $pre %><% $field %>'].value = newaddr['<% $pre %><% $field %>'];
%   } #foreach $field

%   # special case: allow manually setting the census tract, whether 
%   # standardization returned one or not
    if ( cf.elements['old_censustract'].value != cf.elements['enter_censustract'].value
         && cf.elements['enter_censustract'].value.length > 0 ) {
      cf.elements['<% $pre %>censustract'].value = cf.elements['enter_censustract'].value;
    }


    if ( cf.elements['<% $pre %>coord_auto'].value ) {
      cf.elements['<% $pre %>latitude'].value  = newaddr['<% $pre %>latitude'];
      cf.elements['<% $pre %>longitude'].value = newaddr['<% $pre %>longitude'];
    }
%   if ( $withcensus ) {
    if ( clean && newaddr['<% $pre %>censustract'] ) {
      cf.elements['<% $pre %>censustract'].value = newaddr['<% $pre %>censustract'];
    }
%   } #if $withcensus
  } // if clean
% } #foreach $pre

  post_standardization();

}

function confirm_manual_address() {
%# not much to do in this case, just confirm the censustract
% if ( $withcensus ) {
  var cf = document.<% $formname %>;
%   if ( $billship ) {
  if ( cf.elements['same'] && cf.elements['same'].checked ) {
    cf.elements['bill_censustract'].value =
      cf.elements['enter_censustract'].value;
  } else {
    cf.elements['ship_censustract'].value =
      cf.elements['enter_censustract'].value;
  }
%   } else {
  cf.elements['censustract'].value = cf.elements['enter_censustract'].value;
%   }
% }
  post_standardization();
}

function post_standardization() {

% if ( $conf->exists('enable_taxproducts') ) {

  var cf = document.<% $formname %>;

  var prefix = '<% $taxpre %>';
  // fix edge case with cust_main
  if ( cf.elements['same']
    && cf.elements['same'].checked
    && prefix == 'ship_' ) {

    prefix = 'bill_';
  }

  if ( new String(cf.elements[prefix + 'zip'].value).length < 10 )
  {

    var country_el = cf.elements[prefix + 'country'];
    var country = country_el.options[ country_el.selectedIndex ].value;
    var geocode = cf.elements[prefix + 'geocode'].value;

    if ( country == 'CA' || country == 'US' ) {

      var state_el = cf.elements[prefix + 'state'];
      var state = state_el.options[ state_el.selectedIndex ].value;

      var url = "<% $p %>/misc/choose_tax_location.html" +
                  "?data_vendor=cch-zip" + 
                  ";city="     + cf.elements[prefix + 'city'].value +
                  ";state="    + state + 
                  ";zip="      + cf.elements[prefix + 'zip'].value +
                  ";country="  + country +
                  ";geocode="  + geocode +
                  ";formname=" + '<% $formname %>' +
                  ";";

      // popup a chooser
      OLgetAJAX( url, update_geocode, 300 );

    } else {

      cf.elements[prefix + 'geocode'].value = 'DEFAULT';
      <% $post_geocode %>;

    }

  } else {

    cf.elements[prefix + 'geocode'].value = '';
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
    var prefix = '<% $taxpre %>';
    if ( cf.elements['same']
      && cf.elements['same'].checked
      && prefix == 'ship_' ) {
      prefix = 'bill_';
    }

    //alert(what.options[what.selectedIndex].value);
    var argsHash = eval('(' + what.options[what.selectedIndex].value + ')');
    cf.elements[prefix + 'city'].value     = argsHash['city'];
    setselect(cf.elements[prefix + 'state'], argsHash['state']);
    cf.elements[prefix + 'zip'].value      = argsHash['zip'];
    cf.elements[prefix + 'geocode'].value  = argsHash['geocode'];
    <% $post_geocode %>;

  }

  // popup a chooser

  overlib( OLresponseAJAX, CAPTION, 'Select tax location', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, WIDTH, 576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

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

my $withcensus = $opt{'with_census'} ? 1 : 0;

my @prefixes = '';
my $billship = $opt{'billship'} ? 1 : 0; # whether to have bill_ and ship_ prefixes
my $taxpre = '';
# probably should just geocode both addresses, since either one could
# be a package address in the future
if ($billship) {
  @prefixes = qw(bill_ ship_);
  $taxpre = $conf->exists('tax-ship_address') ? 'ship_' : 'bill_';
}

my $formname =  $opt{form} || 'CustomerForm';
my $post_geocode = $opt{callback} || 'post_geocode();';

</%init>
