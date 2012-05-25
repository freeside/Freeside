<& /elements/header.html,
      $title,
      '',
      ' onUnload="myclose()"' #hmm, in billing.html
&>

<& /elements/error.html &>

<FORM NAME   = "CustomerForm"
      METHOD = "POST"
      ACTION = "<% popurl(1) %>process/cust_main.cgi"
>

<INPUT TYPE="hidden" NAME="custnum"     VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="prospectnum" VALUE="<% $prospectnum %>">

% if ( $custnum ) { 
  <% mt('Customer #') |h %><B><% $cust_main->display_custnum %></B> - 
  <B><FONT COLOR="#<% $cust_main->statuscolor %>">
    <% ucfirst($cust_main->status) %>
  </FONT></B>
  <BR><BR>
% } 

%# agent, agent_custid, refnum (advertising source), referral_custnum
%# better section title for this?
<FONT CLASS="fsinnerbox-title"><% mt('Basics') |h %></FONT>
<& cust_main/top_misc.html, $cust_main, 'custnum' => $custnum  &>

%# birthdate
% if (    $conf->exists('cust_main-enable_birthdate')
%      || $conf->exists('cust_main-enable_spouse_birthdate')
%    )
% {
  <BR>
  <& cust_main/birthdate.html, $cust_main &>
% }
% my $has_ship_address = '';
% if ( $cgi->param('error') ) {
%   $has_ship_address = !$cgi->param('same');
% } elsif ( $cust_main->custnum ) {
%   $has_ship_address = $cust_main->has_ship_address;
% }
<BR>
<TABLE> <TR>
  <TD STYLE="width:650px">
%#; padding-right:2px; vertical-align:top">
    <FONT CLASS="fsinnerbox-title"><% mt('Billing address') |h %></FONT>
    <TABLE CLASS="fsinnerbox">
    <& cust_main/before_bill_location.html, $cust_main &>
    <& /elements/location.html,
        object => $cust_main->bill_location,
        prefix => 'bill_',
    &>
    <& cust_main/after_bill_location.html, $cust_main &>
    </TABLE>
  </TD>
</TR>
<TR><TD STYLE="height:40px"></TD></TR>
<TR>
  <TD STYLE="width:650px">
%#; padding-left:2px; vertical-align:top">
    <FONT CLASS="fsinnerbox-title"><% mt('Service address') |h %></FONT>
    <INPUT TYPE="checkbox" 
           NAME="same"
           ID="same"
           onclick="samechanged(this)"
           onkeyup="samechanged(this)"
           VALUE="Y"
           <% $has_ship_address ? '' : 'CHECKED' %>
    ><% mt('same as billing address') |h %>
    <TABLE CLASS="fsinnerbox" ID="table_ship_location">
    <& /elements/location.html,
        object => $cust_main->ship_location,
        prefix => 'ship_',
        enable_censustract => 1,
        enable_district => 1,
    &>
    </TABLE>
    <TABLE CLASS="fsinnerbox" ID="table_ship_location_blank"
    STYLE="display:none">
    <TR><TD></TD></TR>
    </TABLE>
  </TD>
</TR></TABLE>

<SCRIPT>
function samechanged(what) {
%# not display = 'none', because we still want it to take up space
%#  document.getElementById('table_ship_location').style.visibility = 
%#    what.checked ? 'hidden' : 'visible';
  var t1 = document.getElementById('table_ship_location');
  var t2 = document.getElementById('table_ship_location_blank');
  if ( what.checked ) {
    t2.style.width  = t1.clientWidth  + 'px';
    t2.style.height = t1.clientHeight + 'px';
    t1.style.display = 'none';
    t2.style.display = '';
  }
  else {
    t2.style.display = 'none';
    t1.style.display = '';
  }
}
samechanged(document.getElementById('same'));
</SCRIPT>

<BR>

<& cust_main/contacts_new.html,
             'cust_main' => $cust_main,
&>

%# billing info
<& cust_main/billing.html, $cust_main,
               'payinfo'        => $payinfo,
               'invoicing_list' => \@invoicing_list,
&>
<BR>

% my $ro_comments = $conf->exists('cust_main-use_comments')?'':'readonly';
% if (!$ro_comments || $cust_main->comments) {

    <BR>
    <FONT CLASS="fsinnerbox-title"><% mt('Comments') |h %></FONT>
    <TABLE CLASS="fsinnerbox">
      <TR>
        <TD>
          <TEXTAREA NAME = "comments"
                    COLS = 80
                    ROWS = 5
                    WRAP = "HARD"
                    <% $ro_comments %>
          ><% $cust_main->comments %></TEXTAREA>
        </TD>
      </TR>
    </TABLE>

% }

% unless ( $custnum ) {

    <& cust_main/first_pkg.html, $cust_main,
                 'pkgpart_svcpart' => $pkgpart_svcpart,
                 'disable_empty'   =>
                   scalar( $cgi->param('lock_pkgpart') =~ /^(\d+)$/ ),
                 'username'        => $username,
                 'password'        => $password,
                 'popnum'          => $popnum,
                 'saved_domsvc'    => $saved_domsvc,
                 %svc_phone,
                 %svc_dsl,
    &>

% }

<INPUT TYPE="hidden" NAME="locationnum" VALUE="<% $locationnum %>">

<INPUT TYPE="hidden" NAME="usernum" VALUE="<% $cust_main->usernum %>">

%# cust_main/bottomfixup.js
% foreach my $hidden (
%    'payauto', 'billday',
%    'payinfo', 'payinfo1', 'payinfo2', 'payinfo3', 'paytype',
%    'payname', 'paystate', 'exp_month', 'exp_year', 'paycvv',
%    'paystart_month', 'paystart_year', 'payissue',
%    'payip',
%    'paid',
% ) {
    <INPUT TYPE="hidden" NAME="<% $hidden %>" VALUE="">
% } 

<& cust_main/bottomfixup.html, 'custnum' => $custnum &>

<BR>
<INPUT TYPE    = "button"
       NAME    = "submitButton"
       ID      = "submitButton"
       VALUE   = "<% $custnum ?  emt("Apply changes") : emt("Add Customer") %>"
       onClick = "this.disabled=true; bottomfixup(this.form);"
>
<BR><BR>
</FORM>

<& /elements/footer.html &>

<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

#probably redundant given the checks below...
die "access denied"
  unless $curuser->access_right('New customer')
     ||  $curuser->access_right('Edit customer');

my $conf = new FS::Conf;

#get record

my($custnum, $cust_main, $ss, $stateid, $payinfo, @invoicing_list);
my $same = '';
my $pkgpart_svcpart = ''; #first_pkg
my($username, $password, $popnum, $saved_domsvc) = ( '', '', 0, 0 ); #svc_acct
my %svc_phone = ();
my %svc_dsl = ();
my $prospectnum = '';
my $locationnum = '';

if ( $cgi->param('error') ) {

  # false laziness w/ edit/process/cust_main.cgi
  my %locations;
  for my $pre (qw(bill ship)) {
    my %hash;
    foreach ( FS::cust_main->location_fields ) {
      $hash{$_} = scalar($cgi->param($pre.'_'.$_));
    }
    $hash{'custnum'} = $cgi->param('custnum');
    $locations{$pre} = qsearchs('cust_location', \%hash)
                       || FS::cust_location->new( \%hash );
  }

  $cust_main = new FS::cust_main ( {
    map { ( $_, scalar($cgi->param($_)) ) } (fields('cust_main')),
    map { ( "ship_$_", '' ) } (FS::cust_main->location_fields)
  } );

  for my $pre (qw(bill ship)) {
    $cust_main->set($pre.'_location', $locations{$pre});
    $cust_main->set($pre.'_locationnum', $locations{$pre}->locationnum);
  }

  $custnum = $cust_main->custnum;

  die "access denied"
    unless $curuser->access_right($custnum ? 'Edit customer' : 'New customer');

  @invoicing_list = split( /\s*,\s*/, $cgi->param('invoicing_list') );
  $same = $cgi->param('same');
  $cust_main->setfield('paid' => $cgi->param('paid')) if $cgi->param('paid');
  $ss = $cust_main->ss;           # don't mask an entered value on errors
  $stateid = $cust_main->stateid; # don't mask an entered value on errors
  $payinfo = $cust_main->payinfo; # don't mask an entered value on errors

  $prospectnum = $cgi->param('prospectnum') || '';

  $pkgpart_svcpart = $cgi->param('pkgpart_svcpart') || '';

  $locationnum = $cgi->param('locationnum') || '';

  #svc_acct
  $username = $cgi->param('username');
  $password = $cgi->param('_password');
  $popnum = $cgi->param('popnum');
  $saved_domsvc = $cgi->param('domsvc') || '';
  if ( $saved_domsvc =~ /^(\d+)$/ ) {
    $saved_domsvc = $1;
  } else {
    $saved_domsvc = '';
  }

  #svc_phone
  $svc_phone{$_} = $cgi->param($_)
    foreach qw( countrycode phonenum sip_password pin phone_name );

  #svc_dsl (phonenum came in with svc_phone)
  $svc_phone{$_} = $cgi->param($_)
    foreach qw( password isp_chg isp_prev vendor_qual_id );

} elsif ( $cgi->keywords ) { #editing

  die "access denied"
    unless $curuser->access_right('Edit customer');

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
  @invoicing_list = $cust_main->invoicing_list;
  $ss = $conf->exists('unmask_ss') ? $cust_main->ss : $cust_main->masked('ss');
  $stateid = $cust_main->masked('stateid');
  $payinfo = $cust_main->paymask;

} else { #new customer

  die "access denied"
    unless $curuser->access_right('New customer');

  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->agentnum( $conf->config('default_agentnum') )
    if $conf->exists('default_agentnum');
  $cust_main->otaker( &getotaker );
  $cust_main->referral_custnum( $cgi->param('referral_custnum') );
  @invoicing_list = ();
  push @invoicing_list, 'POST'
    unless $conf->exists('disablepostalinvoicedefault');
  $ss = '';
  $stateid = '';
  $payinfo = '';

  if ( $cgi->param('qualnum') =~ /^(\d+)$/ ) {
    my $qualnum = $1;
    my $qual = qsearchs('qual', { 'qualnum' => $qualnum } )
      or die "unknown qualnum $qualnum";

    my $prospect_main = $qual->cust_or_prospect;
    $prospectnum = $prospect_main->prospectnum
      or die "qualification not on a prospect";

    $cust_main->agentnum( $prospect_main->agentnum );
    $cust_main->company(  $prospect_main->company  );

    #first contact? -> name
    my @contacts = $prospect_main->contact;
    my $contact = $contacts[0];
    $cust_main->first( $contact->first );
    $cust_main->set( 'last', $contact->get('last') );
    #contact phone numbers?

    #location -> address  (all prospect quals have location, right?)
    my $cust_location = $qual->cust_location;
    $cust_location->dealternize;
    $cust_main->$_( $cust_location->$_ )
      foreach qw( address1 address2 city county state zip country latitude longitude coord_auto geocode );

    #locationnum -> package order
    $locationnum = $qual->locationnum;

    #pkgpart handled by lock_pkgpart below

    #service telephone & vendor_qual_id -> svc_dsl
    $svc_dsl{$_} = $qual->$_
      foreach qw( phonenum vendor_qual_id );
  }
  else {
    my $countrydefault = $conf->config('countrydefault') || 'US';
    my $statedefault = $conf->config('statedefault') || 'CA';
    $cust_main->set('bill_location', 
      FS::cust_location->new(
        { country => $countrydefault, state => $statedefault }
      )
    );
    $cust_main->set('ship_location',
      FS::cust_location->new(
        { country => $countrydefault, state => $statedefault }
      )
    );
  }

  if ( $cgi->param('lock_pkgpart') =~ /^(\d+)$/ ) {
    my $pkgpart = $1;
    my $part_pkg = qsearchs('part_pkg', { 'pkgpart' => $pkgpart } )
      or die "unknown pkgpart $pkgpart";
    my $svcpart = $part_pkg->svcpart;
    $pkgpart_svcpart = $pkgpart.'_'.$svcpart;
  }

}

my %keep = map { $_=>1 } qw( error tagnum lock_agentnum lock_pkgpart );
$cgi->delete( grep { !$keep{$_} && $_ !~ /^tax_/ } $cgi->param );

my $title = $custnum ? 'Edit Customer' : 'Add Customer';
$title = mt($title);
$title .= ": ". $cust_main->name if $custnum;

my $r = qq!<font color="#ff0000">*</font>&nbsp;!;

</%init>
