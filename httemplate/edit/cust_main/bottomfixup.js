<%init>
my %opt = @_; # custnum
my $conf = new FS::Conf;

my $company_latitude  = $conf->config('company_latitude');
my $company_longitude = $conf->config('company_longitude');

my @fixups = ('copy_payby_fields', 'standardize_locations');

push @fixups, 'confirm_censustract_bill', 'confirm_censustract_ship'
    if $conf->exists('cust_main-require_censustract');

my $uniqueness = $conf->config('cust_main-check_unique');
push @fixups, 'check_unique'
    if $uniqueness and !$opt{'custnum'};

push @fixups, 'do_submit'; # always last
</%init>
var fixups = <% encode_json(\@fixups) %>;
var fixup_position;
var running = false;

<&| /elements/onload.js &>
submit_abort();
</&>

%# state machine to deal with all the asynchronous stuff we're doing
%# call this after each fixup on success:
function submit_continue() {
  if ( running ) {
    window[ fixups[fixup_position++] ].call();
  }
}

%# or on failure:
function submit_abort() {
  running = false;
  fixup_position = 0;
  document.CustomerForm.submitButton.disabled = false;
  cClick();
}

function bottomfixup(what) {
  fixup_position = 0;
  document.CustomerForm.submitButton.disabled = true;
  running = true;
  submit_continue();
}

function do_submit() {
  document.CustomerForm.submit();
}

function copy_payby_fields() {
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
  submit_continue();
}

<& /elements/standardize_locations.js,
  'callback' => 'submit_continue();',
  'billship' => 1,
  'with_census' => 1, # no with_firm, apparently
&>

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

% # the value in pre+'censustract' is the confirmed censustract; if it's set,
% # and the user hasn't changed it manually, skip this
function confirm_censustract(pre) {
  var cf = document.CustomerForm;
  if ( cf.elements[pre+'censustract'].value == '' ||
         cf.elements[pre+'enter_censustract'].value != 
         cf.elements[pre+'censustract'].value )
  {
    var address_info = form_address_info();
    address_info[pre+'latitude']  = cf.elements[pre+'latitude'].value;
    address_info[pre+'longitude'] = cf.elements[pre+'longitude'].value;
    address_info['prefix'] = pre;
    OLpostAJAX(
        '<%$p%>/misc/confirm-censustract.html',
        'q=' + encodeURIComponent(JSON.stringify(address_info)),
        function() {
          if ( OLresponseAJAX ) {
            overlib( OLresponseAJAX, CAPTION, 'Confirm censustract', STICKY,
              AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH,
              576, HEIGHT, 268, BGCOLOR, '#333399', CGCOLOR, '#333399',
              TEXTSIZE, 3 );
          } else
            submit_continue();
        },
        0);
  } else submit_continue();
}
function confirm_censustract_bill() {
  confirm_censustract('bill_');
}

function confirm_censustract_ship() {
  var cf = document.CustomerForm;
  if ( cf.elements['same'].checked ) {
    submit_continue();
  } else {
    confirm_censustract('ship_');
  }
}

%# called from confirm-censustract.html
function set_censustract(tract, year, pre) {
  var cf = document.CustomerForm;
  cf.elements[pre + 'censustract'].value = tract;
  cf.elements[pre + 'censusyear'].value = year;
  submit_continue();
}

function check_unique() {
  var search_hash = {};
% if ($uniqueness eq 'address') {
  search_hash['address'] = [
    document.CustomerForm.elements['bill_address1'].value,
    document.CustomerForm.elements['ship_address1'].value
  ];
% }
%# no other options yet

%# supported in IE8+, Firefox 3.5+, WebKit, Opera 10.5+
  duplicates_form(JSON.stringify(search_hash), confirm_unique);
}

function confirm_unique(arg) {
  if ( arg.match(/\S/) ) {
%# arg contains a complete form to choose an existing customer, or not
  overlib( arg, CAPTION, 'Duplicate customer', STICKY, AUTOSTATUSCAP, 
      CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, 
      268, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );
  } else { // no duplicates
    submit_continue();
  }
}

