<% include('/elements/header.html',
      "Customer $action",
      '',
      ' onUnload="myclose()"'
) %>

<% include('/elements/init_overlib.html') %>

<% include('/elements/error.html') %>

<FORM NAME="topform" STYLE="margin-bottom: 0">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">

% if ( $custnum ) { 
  Customer #<B><% $custnum %></B> - 
  <B><FONT COLOR="#<% $cust_main->statuscolor %>">
    <% ucfirst($cust_main->status) %>
  </FONT></B>
  <BR><BR>
% } 

<% &ntable("#cccccc") %>

%# agent
<% include('/elements/tr-select-agent.html', 
              'curr_value'    => $cust_main->agentnum,
              'label'         => "<B>${r}Agent</B>",
              'empty_label'   => 'Select agent',
              'disable_empty' => ( $cust_main->agentnum ? 1 : 0 ),
           )
%>

%# agent_custid
% if ( $conf->exists('cust_main-edit_agent_custid') ) {

    <TR>
      <TD ALIGN="right">Customer identifier</TD>
      <TD><INPUT TYPE="text" NAME="agent_custid" VALUE="<% $cust_main->agent_custid %>"></TD>
    </TR>

% } else {

    <INPUT TYPE="hidden" NAME="agent_custid" VALUE="<% $cust_main->agent_custid %>">

% }

%# referral (advertising source)
%my $refnum = $cust_main->refnum || $conf->config('referraldefault') || 0;
%if ( $custnum && ! $conf->exists('editreferrals') ) {

  <INPUT TYPE="hidden" NAME="refnum" VALUE="<% $refnum %>">

% } else { 

   <% include('/elements/tr-select-part_referral.html',
                'curr_value' => $refnum
             )
   %>
% } 


%# referring customer
%my $referring_cust_main = '';
%if ( $cust_main->referral_custnum
%     and $referring_cust_main =
%           qsearchs('cust_main', { custnum => $cust_main->referral_custnum } )
%) {

  <TR>
    <TD ALIGN="right">Referring customer</TD>
    <TD>
      <A HREF="<% popurl(1) %>/cust_main.cgi?<% $cust_main->referral_custnum %>"><% $cust_main->referral_custnum %>: <% $referring_cust_main->name %></A>
    </TD>
  </TR>
  <INPUT TYPE="hidden" NAME="referral_custnum" VALUE="<% $cust_main->referral_custnum %>">
% } elsif ( ! $conf->exists('disable_customer_referrals') ) { 


  <TR>
    <TD ALIGN="right">Referring customer</TD>
    <TD>
      <!-- <INPUT TYPE="text" NAME="referral_custnum" VALUE=""> -->
      <% include('/elements/search-cust_main.html',
                    'field_name' => 'referral_custnum',
                 )
      %>
    </TD>
  </TR>
% } else { 


  <INPUT TYPE="hidden" NAME="referral_custnum" VALUE="">
% } 


</TABLE>

<!-- birthdate -->

% if ( $conf->exists('cust_main-enable_birthdate') ) {

  <BR>
  <% ntable("#cccccc", 2) %>
  <% include ('/elements/tr-input-date-field.html',
              'birthdate',
              $cust_main->birthdate,
              'Date of Birth',
              $conf->config('date_format') || "%m/%d/%Y",
              1)
  %>

  </TABLE>

% }

<!-- contact info -->

%  my $same_checked = '';
%  my $ship_disabled = '';
%  unless ( $cust_main->ship_last && $same ne 'Y' ) {
%    $same_checked = 'CHECKED';
%    $ship_disabled = 'DISABLED STYLE="background-color: #dddddd"';
%    foreach (
%      qw( last first company address1 address2 city county state zip country
%          daytime night fax )
%    ) {
%      $cust_main->set("ship_$_", $cust_main->get($_) );
%    }
%  }

<BR><BR>
Billing address
<% include('cust_main/contact.html',
             'cust_main'    => $cust_main,
             'pre'          => '',
             'onchange'     => 'bill_changed(this)',
             'disabled'     => '',
             'ss'           => $ss,
             'stateid'      => $stateid,
             'same_checked' => $same_checked, #for address2 "Unit #" labeling
          )
%>

<SCRIPT>
function bill_changed(what) {
  if ( what.form.same.checked ) {
% for (qw( last first company address1 address2 city zip daytime night fax )) { 

    what.form.ship_<%$_%>.value = what.form.<%$_%>.value;
% } 

    what.form.ship_country.selectedIndex = what.form.country.selectedIndex;

    function fix_ship_county() {
      what.form.ship_county.selectedIndex = what.form.county.selectedIndex;
    }

    function fix_ship_state() {
      what.form.ship_state.selectedIndex = what.form.state.selectedIndex;
      ship_state_changed(what.form.ship_state, fix_ship_county );
    }

    ship_country_changed(what.form.ship_country, fix_ship_state );

  }
}
function samechanged(what) {
  if ( what.checked ) {
    bill_changed(what);

%   for (qw( last first company address1 address2 city county state zip country daytime night fax )) { 
      what.form.ship_<%$_%>.disabled = true;
      what.form.ship_<%$_%>.style.backgroundColor = '#dddddd';
%   } 

%   if ( $conf->exists('cust_main-require_address2') ) {
      document.getElementById('address2_required').style.visibility = '';
      document.getElementById('address2_label').style.visibility = '';
      document.getElementById('ship_address2_required').style.visibility = 'hidden';
      document.getElementById('ship_address2_label').style.visibility = 'hidden';
%   }

  } else {

%   for (qw( last first company address1 address2 city county state zip country daytime night fax )) { 
      what.form.ship_<%$_%>.disabled = false;
      what.form.ship_<%$_%>.style.backgroundColor = '#ffffff';
%   } 

%   if ( $conf->exists('cust_main-require_address2') ) {
      document.getElementById('address2_required').style.visibility = 'hidden';
      document.getElementById('address2_label').style.visibility = 'hidden';
      document.getElementById('ship_address2_required').style.visibility = '';
      document.getElementById('ship_address2_label').style.visibility = '';
%   }

  }
}
</SCRIPT>

<BR>
Service address 
(<INPUT TYPE="checkbox" NAME="same" VALUE="Y" onClick="samechanged(this)" <%$same_checked%>>same as billing address)
<% include('cust_main/contact.html',
             'cust_main' => $cust_main,
             'pre'       => 'ship_',
             'onchange'  => '',
             'disabled'  => $ship_disabled,
          )
%>


<!-- billing info -->

<% include( 'cust_main/billing.html', $cust_main,
               'payinfo'        => $payinfo,
               'invoicing_list' => \@invoicing_list,
           )
%>

<% include( '/elements/xmlhttp.html',
              'url'  => $p.'misc/xmlhttp-cust_main-address_standardize.html',
              'subs' => [ 'address_standardize' ],
              #'method' => 'POST', #could get too long?
          )
%>

<SCRIPT>
function bottomfixup(what) {

  //i don't think we need to copy things between two forms anymore, modern
  //browsers are fine with DIVs inside FORMs

  var topvars = new Array(
    'birthdate',

    'custnum', 'agentnum', 'agent_custid', 'refnum', 'referral_custnum',

    'last', 'first', 'ss', 'company',
    'address1', 'address2', 'city',
    'county', 'state', 'zip', 'country',
    'daytime', 'night', 'fax',
    'stateid', 'stateid_state',

    'same',

    'ship_last', 'ship_first', 'ship_company',
    'ship_address1', 'ship_address2', 'ship_city',
    'ship_county', 'ship_state', 'ship_zip', 'ship_country',
    'ship_daytime','ship_night', 'ship_fax',

    'select' // XXX key
  );

  var layervars = new Array(
    'payauto',
    'payinfo', 'payinfo1', 'payinfo2', 'paytype',
    'payname', 'paystate', 'exp_month', 'exp_year', 'paycvv',
    'paystart_month', 'paystart_year', 'payissue',
    'payip',
    'paid'
  );

  var billing_bottomvars = new Array(
    'tax',
    'invoicing_list', 'invoicing_list_POST', 'invoicing_list_FAX',
    'invoice_terms',
    'spool_cdr',
    'squelch_cdr'
  );

  for ( f=0; f < topvars.length; f++ ) {
    var field = topvars[f];
    copyelement( document.topform.elements[field],
                 document.bottomform.elements[field]
               );
  }

  var layerform = document.topform.select.options[document.topform.select.selectedIndex].value;
  for ( f=0; f < layervars.length; f++ ) {
    var field = layervars[f];
    copyelement( document.forms[layerform].elements[field],
                 document.bottomform.elements[field]
               );
  }

  for ( f=0; f < billing_bottomvars.length; f++ ) {
    var field = billing_bottomvars[f];
    copyelement( document.billing_bottomform.elements[field],
                 document.bottomform.elements[field]
               );
  }

  //this part does USPS address correction

  // XXX should this be first and should we update the form fields that are
  // displayed???

  //var state_el = document.bottomform.elements['state'];

  //address_standardize(
  var cust_main = new Array(
    'company',  document.bottomform.elements['company'].value,
    'address1', document.bottomform.elements['address1'].value,
    'address2', document.bottomform.elements['address2'].value,
    'city',     document.bottomform.elements['city'].value,
    'state',    document.bottomform.elements['state'].value,
    //'state',    state_el.options[ state_el.selectedIndex ].value,
    'zip',      document.bottomform.elements['zip'].value,

    'ship_company',  document.bottomform.elements['ship_company'].value,
    'ship_address1', document.bottomform.elements['ship_address1'].value,
    'ship_address2', document.bottomform.elements['ship_address2'].value,
    'ship_city',     document.bottomform.elements['ship_city'].value,
    'ship_state',    document.bottomform.elements['ship_state'].value,
    //'ship_state',    state_el.options[ state_el.selectedIndex ].value,
    'ship_zip',      document.bottomform.elements['ship_zip'].value
  );

  address_standardize( cust_main, update_address );

}

var standardize_address;

function update_address(arg) {

  var argsHash = eval('(' + arg + ')');

  var changed  = argsHash['address_standardized'];
  var ship_changed = argsHash['ship_address_standardized'];

  //yay closures
  standardize_address = function () {

    if ( changed ) {
      document.bottomform.elements['company'].value = argsHash['new_company'];
      document.bottomform.elements['address1'].value = argsHash['new_address1'];
      document.bottomform.elements['address2'].value = argsHash['new_address2'];
      document.bottomform.elements['city'].value = argsHash['new_city'];
      document.bottomform.elements['state'].value = argsHash['new_state'];
  //'state',    state_el.options[ state_el.selectedIndex ].value,
      document.bottomform.elements['zip'].value = argsHash['new_zip'];
    }

    if ( ship_changed ) {
      document.bottomform.elements['ship_company'].value = argsHash['new_ship_company'];
      document.bottomform.elements['ship_address1'].value = argsHash['new_ship_address1'];
      document.bottomform.elements['ship_address2'].value = argsHash['new_ship_address2'];
      document.bottomform.elements['ship_city'].value = argsHash['new_ship_city'];
      document.bottomform.elements['ship_state'].value = argsHash['new_ship_state'];
  //'state',    state_el.options[ state_el.selectedIndex ].value,
      document.bottomform.elements['ship_zip'].value = argsHash['new_ship_zip'];
    }

  }

  if ( changed || ship_changed ) {

%   if ( $conf->exists('cust_main-auto_standardize_address') ) {

    standardize_address();
    document.bottomform.submit();

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
        '<BUTTON TYPE="button" onClick="document.bottomform.submit();"><IMG SRC="<%$p%>images/error.png" ALT=""> Use entered ' + addresses + '</BUTTON>' + 
      '</TD><TD>' +
        '<BUTTON TYPE="button" onClick="standardize_address(); document.bottomform.submit();"><IMG SRC="<%$p%>images/tick.png" ALT=""> Use standardized ' + addresses + '</BUTTON>' + 
      '</TD></TR>' +
      '<TR><TD COLSPAN=2 ALIGN="center">' +
        '<BUTTON TYPE="button" onClick="document.bottomform.submitButton.disabled=false; parent.cClick();"><IMG SRC="<%$p%>images/cross.png" ALT=""> Cancel submission</BUTTON></TD></TR>' +
        
      '</TABLE></CENTER>';

    overlib( confirm_change, CAPTION, 'Confirm address standardization', STICKY, AUTOSTATUSCAP, CLOSETEXT, '', MIDX, 0, MIDY, 0, DRAGGABLE, WIDTH, 576, HEIGHT, height, BGCOLOR, '#333399', CGCOLOR, '#333399', TEXTSIZE, 3 );

%   }

  } else {

    document.bottomform.submit();

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

</SCRIPT>

<FORM ACTION="<% popurl(1) %>process/cust_main.cgi" METHOD=POST NAME="bottomform" STYLE="margin-top: 0; margin-bottom: 0">
% foreach my $hidden (
%     'birthdate',
%
%     'custnum', 'agentnum', 'agent_custid', 'refnum', 'referral_custnum',
%     'last', 'first', 'ss', 'company',
%     'address1', 'address2', 'city',
%     'county', 'state', 'zip', 'country',
%     'daytime', 'night', 'fax',
%     'stateid', 'stateid_state',
%     
%     'same',
%     
%     'ship_last', 'ship_first', 'ship_company',
%     'ship_address1', 'ship_address2', 'ship_city',
%     'ship_county', 'ship_state', 'ship_zip', 'ship_country',
%     'ship_daytime','ship_night', 'ship_fax',
%     
%     'select', #XXX key
%
%     'payauto',
%     'payinfo', 'payinfo1', 'payinfo2', 'paytype',
%     'payname', 'paystate', 'exp_month', 'exp_year', 'paycvv',
%     'paystart_month', 'paystart_year', 'payissue',
%     'payip',
%     'paid',
%     
%     'tax',
%     'invoicing_list', 'invoicing_list_POST', 'invoicing_list_FAX',
%     'invoice_terms',
%     'spool_cdr',
%     'squelch_cdr'
%   ) {
%

  <INPUT TYPE="hidden" NAME="<% $hidden %>" VALUE="">
% } 
%
% my $ro_comments = $conf->exists('cust_main-use_comments')?'':'readonly';
% if (!$ro_comments || $cust_main->comments) {

<BR>Comments
<% &ntable("#cccccc") %>
  <TR>
    <TD>
      <TEXTAREA COLS=80 ROWS=5 WRAP="HARD" NAME="comments" <%$ro_comments%>><% $cust_main->comments %></TEXTAREA>
    </TD>
  </TR>
</TABLE>
%
% }
%
%unless ( $custnum ) {
%  # pry the wrong place for this logic.  also pretty expensive
%  #use FS::part_pkg;
%
%  #false laziness, copied from FS::cust_pkg::order
%  my $pkgpart;
%  my @agents = $FS::CurrentUser::CurrentUser->agents;
%  if ( scalar(@agents) == 1 ) {
%    # $pkgpart->{PKGPART} is true iff $custnum may purchase PKGPART
%    $pkgpart = $agents[0]->pkgpart_hashref;
%  } else {
%    #can't know (agent not chosen), so, allow all
%    my %typenum;
%    foreach my $agent ( @agents ) {
%      next if $typenum{$agent->typenum}++;
%      #fixed in 5.004_05 #$pkgpart->{$_}++ foreach keys %{ $agent->pkgpart_hashref }
%      foreach ( keys %{ $agent->pkgpart_hashref } ) { $pkgpart->{$_}++; } #5.004_04 workaround
%    }
%  }
%  #eslaf
%
%  my @part_pkg = grep { $_->svcpart('svc_acct') && $pkgpart->{ $_->pkgpart } }
%    qsearch( 'part_pkg', { 'disabled' => '' }, '', 'ORDER BY pkg' ); # case?
%
%  if ( @part_pkg ) {
%
%    #    print "<BR><BR>First package", &itable("#cccccc", "0 ALIGN=LEFT"),
%    #apiabuse & undesirable wrapping
%
%    

    <BR>First package
    <% ntable("#cccccc") %>
    
      <TR>
        <TD COLSPAN=2>
          <% include('cust_main/select-domain.html',
                       'pkgparts'      => \@part_pkg,
                       'saved_pkgpart' => $saved_pkgpart,
                       'saved_domsvc' => $saved_domsvc,
                    )
          %>
        </TD>
      </TR>
% 
%        #false laziness: (mostly) copied from edit/svc_acct.cgi
%        #$ulen = $svc_acct->dbdef_table->column('username')->length;
%        my $ulen = dbdef->table('svc_acct')->column('username')->length;
%        my $ulen2 = $ulen+2;
%        my $passwordmax = $conf->config('passwordmax') || 8;
%        my $pmax2 = $passwordmax + 2;
%      

    
      <TR>
        <TD ALIGN="right">Username</TD>
        <TD>
          <INPUT TYPE="text" NAME="username" VALUE="<% $username %>" SIZE=<% $ulen2 %> MAXLENGTH=<% $ulen %>>
        </TD>
      </TR>
    
      <TR>
        <TD ALIGN="right">Domain</TD>
        <TD>
          <SELECT NAME="domsvc">
            <OPTION>(none)</OPTION>
          </SELECT>
        </TD>
      </TR>
    
      <TR>
        <TD ALIGN="right">Password</TD>
        <TD>
          <INPUT TYPE="text" NAME="_password" VALUE="<% $password %>" SIZE=<% $pmax2 %> MAXLENGTH=<% $passwordmax %>>
          (blank to generate)
        </TD>
      </TR>
    
      <TR>
        <TD ALIGN="right">Access number</TD>
        <TD><% FS::svc_acct_pop::popselector($popnum) %></TD>
      </TR>
    </TABLE>
% } 
% } 


<INPUT TYPE="hidden" NAME="otaker" VALUE="<% $cust_main->otaker %>">
<BR>
<INPUT TYPE="button" NAME="submitButton" ID="submitButton" VALUE="<% $custnum ?  "Apply Changes" : "Add Customer" %>" onClick="document.bottomform.submitButton.disabled=true; bottomfixup(this.form);">
<BR>
</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit customer');

#for misplaced logic below
#use FS::part_pkg;

#for false laziness below (now more properly lazy)
#use FS::svc_acct_pop;

#for (other) false laziness below
#use FS::agent;
#use FS::type_pkgs;

my $conf = new FS::Conf;

#get record

my($custnum, $username, $password, $popnum, $cust_main, $saved_pkgpart, $saved_domsvc);
my(@invoicing_list);
my ($ss,$stateid,$payinfo);
my $same = '';
if ( $cgi->param('error') ) {
  $cust_main = new FS::cust_main ( {
    map { $_, scalar($cgi->param($_)) } fields('cust_main')
  } );
  $custnum = $cust_main->custnum;
  $saved_domsvc = $cgi->param('domsvc') || '';
  if ( $saved_domsvc =~ /^(\d+)$/ ) {
    $saved_domsvc = $1;
  } else {
    $saved_domsvc = '';
  }
  $saved_pkgpart = $cgi->param('pkgpart_svcpart') || '';
  if ( $saved_pkgpart =~ /^(\d+)_/ ) {
    $saved_pkgpart = $1;
  } else {
    $saved_pkgpart = '';
  }
  $username = $cgi->param('username');
  $password = $cgi->param('_password');
  $popnum = $cgi->param('popnum');
  @invoicing_list = split( /\s*,\s*/, $cgi->param('invoicing_list') );
  $same = $cgi->param('same');
  $cust_main->setfield('paid' => $cgi->param('paid')) if $cgi->param('paid');
  $ss = $cust_main->ss;           # don't mask an entered value on errors
  $stateid = $cust_main->stateid; # don't mask an entered value on errors
  $payinfo = $cust_main->payinfo; # don't mask an entered value on errors
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum=$1;
  $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  if ( $cust_main->dbdef_table->column('paycvv')
       && length($cust_main->paycvv)             ) {
    my $paycvv = $cust_main->paycvv;
    $paycvv =~ s/./*/g;
    $cust_main->paycvv($paycvv);
  }
  $saved_pkgpart = 0;
  $saved_domsvc = 0;
  $username = '';
  $password = '';
  $popnum = 0;
  @invoicing_list = $cust_main->invoicing_list;
  $ss = $cust_main->masked('ss');
  $stateid = $cust_main->masked('stateid');
  $payinfo = $cust_main->paymask;
} else {
  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->otaker( &getotaker );
  $cust_main->referral_custnum( $cgi->param('referral_custnum') );
  $saved_pkgpart = 0;
  $saved_domsvc = 0;
  $username = '';
  $password = '';
  $popnum = 0;
  @invoicing_list = ();
  push @invoicing_list, 'POST'
    unless $conf->exists('disablepostalinvoicedefault');
  $ss = '';
  $stateid = '';
  $payinfo = '';
}

my $error = $cgi->param('error');
$cgi->delete_all();
$cgi->param('error', $error);

my $action = $custnum ? 'Edit' : 'Add';
$action .= ": ". $cust_main->name if $custnum;

my $r = qq!<font color="#ff0000">*</font>&nbsp;!;

</%init>
