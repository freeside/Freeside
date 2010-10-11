function standardize_locations() {

  var cf = document.<% $formname %>;

  var state_el      = cf.elements['<% $main_prefix %>state'];
  var ship_state_el = cf.elements['<% $ship_prefix %>state'];

  var address_info = new Array(
% if ( $onlyship ) {
    'onlyship', 1,
% } else {
%   if ( $withfirm ) {
    'company',  cf.elements['<% $main_prefix %>company'].value,
%   }
    'address1', cf.elements['<% $main_prefix %>address1'].value,
    'address2', cf.elements['<% $main_prefix %>address2'].value,
    'city',     cf.elements['<% $main_prefix %>city'].value,
    'state',    state_el.options[ state_el.selectedIndex ].value,
    'zip',      cf.elements['<% $main_prefix %>zip'].value,
% }
% if ( $withfirm ) {
    'ship_company',  cf.elements['<% $ship_prefix %>company'].value,
% }
    'ship_address1', cf.elements['<% $ship_prefix %>address1'].value,
    'ship_address2', cf.elements['<% $ship_prefix %>address2'].value,
    'ship_city',     cf.elements['<% $ship_prefix %>city'].value,
    'ship_state',    ship_state_el.options[ ship_state_el.selectedIndex ].value,
    'ship_zip',      cf.elements['<% $ship_prefix %>zip'].value
  );

  address_standardize( address_info, update_address );

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

    var cf = document.<% $formname %>;
    var state_el      = cf.elements['<% $main_prefix %>state'];
    var ship_state_el = cf.elements['<% $ship_prefix %>state'];

% if ( !$onlyship ) {
    if ( changed ) {
%   if ( $withfirm ) {
      cf.elements['<% $main_prefix %>company'].value  = argsHash['new_company'];
%   }
      cf.elements['<% $main_prefix %>address1'].value = argsHash['new_address1'];
      cf.elements['<% $main_prefix %>address2'].value = argsHash['new_address2'];
      cf.elements['<% $main_prefix %>city'].value     = argsHash['new_city'];
      setselect(cf.elements['<% $main_prefix %>state'], argsHash['new_state']);
      cf.elements['<% $main_prefix %>zip'].value      = argsHash['new_zip'];
    }
% }

    if ( ship_changed ) {
% if ( $withfirm ) {
      cf.elements['<% $ship_prefix %>company'].value  = argsHash['new_ship_company'];
% }
      cf.elements['<% $ship_prefix %>address1'].value = argsHash['new_ship_address1'];
      cf.elements['<% $ship_prefix %>address2'].value = argsHash['new_ship_address2'];
      cf.elements['<% $ship_prefix %>city'].value     = argsHash['new_ship_city'];
      setselect(cf.elements['<% $ship_prefix %>state'], argsHash['new_ship_state']);
      cf.elements['<% $ship_prefix %>zip'].value      = argsHash['new_ship_zip'];
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
        '<BUTTON TYPE="button" onClick="document.<% $formname %>.submitButton.disabled=false; parent.cClick();"><IMG SRC="<%$p%>images/cross.png" ALT=""> Cancel submission</BUTTON></TD></TR>' +
        
      '</TABLE></CENTER>';

    overlib( confirm_change, CAPTION, 'Confirm address standardization', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, height, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

%   }

  } else {

    post_standardization();

  }


}

function post_standardization() {

  var cf = document.<% $formname %>;

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

my $formname =  $opt{form} || 'CustomerForm';
my $onlyship =  $opt{onlyship} || '';
my $main_prefix =  $opt{main_prefix} || '';
my $ship_prefix =  $opt{ship_prefix} || ($onlyship ? '' : 'ship_');
my $taxpre = $main_prefix;
$taxpre = $ship_prefix if ( $conf->exists('tax-ship_address') || $onlyship );
my $post_geocode = $opt{callback} || 'post_geocode();';
$withfirm = 0 if $opt{no_company};

</%init>
