<%

  #for misplaced logic below
  #use FS::part_pkg;

  #for false laziness below (now more properly lazy)
  #use FS::svc_acct_pop;

  #for (other) false laziness below
  #use FS::agent;
  #use FS::type_pkgs;

my $conf = new FS::Conf;

#get record

my $error = '';
my($custnum, $username, $password, $popnum, $cust_main, $saved_pkgpart);
my(@invoicing_list);
my $same = '';
if ( $cgi->param('error') ) {
  $error = $cgi->param('error');
  $cust_main = new FS::cust_main ( {
    map { $_, scalar($cgi->param($_)) } fields('cust_main')
  } );
  $custnum = $cust_main->custnum;
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
  $username = '';
  $password = '';
  $popnum = 0;
  @invoicing_list = $cust_main->invoicing_list;
} else {
  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->otaker( &getotaker );
  $cust_main->referral_custnum( $cgi->param('referral_custnum') );
  $saved_pkgpart = 0;
  $username = '';
  $password = '';
  $popnum = 0;
  @invoicing_list = ();
}
$cgi->delete_all();
my $action = $custnum ? 'Edit' : 'Add';

%>

<!-- top -->

<%= header("Customer $action", '', ' onUnload="myclose()"') %>

<% if ( $error ) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%= $error %></FONT>
<% } %>

<FORM NAME="topform" STYLE="margin-bottom: 0">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<%= $custnum %>">
Customer # <%= $custnum ? "<B>$custnum</B>" : " (NEW)" %>

<!-- agent -->

<%

my $r = qq!<font color="#ff0000">*</font>&nbsp;!;

my %agent_search = dbdef->table('agent')->column('disabled')
                     ? ( 'disabled' => '' ) : ();
my @agents = qsearch( 'agent', \%agent_search );
#die "No agents created!" unless @agents;
eidiot "You have not created any agents (or all agents are disabled).  You must create at least one agent before adding a customer.  Go to ". popurl(2). "browse/agent.cgi and create one or more agents." unless @agents;
my $agentnum = $cust_main->agentnum || $agents[0]->agentnum; #default to first

%>

<% if ( scalar(@agents) == 1 ) { %>
  <INPUT TYPE="hidden" NAME="agentnum" VALUE="<%= $agentnum %>">
<% } else { %>
  <BR><BR><%=$r%>Agent <SELECT NAME="agentnum" SIZE="1">
  <% foreach my $agent (sort { $a->agent cmp $b->agent; } @agents) { %>
    <OPTION VALUE="<%= $agent->agentnum %>"<%= " SELECTED"x($agent->agentnum==$agentnum) %>><%= $agent->agent %>
  <% } %>
  </SELECT>
<% } %>

<!-- referral (advertising source) -->

<%
my $refnum = $cust_main->refnum || $conf->config('referraldefault') || 0;
if ( $custnum && ! $conf->exists('editreferrals') ) {
%>

  <INPUT TYPE="hidden" NAME="refnum" VALUE="<%= $refnum %>">

<%
 } else {

   my(@referrals) = qsearch('part_referral',{});
   if ( scalar(@referrals) == 0 ) {
     eidiot "You have not created any advertising sources.  You must create at least one advertising source before adding a customer.  Go to ". popurl(2). "browse/part_referral.cgi and create one or more advertising sources.";
   } elsif ( scalar(@referrals) == 1 ) {
     $refnum ||= $referrals[0]->refnum;
%>

     <INPUT TYPE="hidden" NAME="refnum" VALUE="<%= $refnum %>">

<% } else { %>

     <BR><BR><%=$r%>Advertising source 
     <SELECT NAME="refnum" SIZE="1">
       <%= $refnum ? '' : '<OPTION VALUE="">' %>
       <% foreach my $referral (sort { $a->refnum <=> $b->refnum } @referrals) { %>
         <OPTION VALUE="<%= $referral->refnum %>" <%= $referral->refnum == $refnum ? 'SELECTED' : '' %>><%= $referral->refnum %>: <%= $referral->referral %>
       <% } %>
     </SELECT>
<% } %>

<% } %>

<!-- referring customer -->

<%
my $referring_cust_main = '';
if ( $cust_main->referral_custnum
     and $referring_cust_main =
           qsearchs('cust_main', { custnum => $cust_main->referral_custnum } )
) {
%>

  <BR><BR>Referring Customer: 
  <A HREF="<%= popurl(1) %>/cust_main.cgi?<%= $cust_main->referral_custnum %>"><%= $cust_main->referral_custnum %>: <%= $referring_cust_main->name %></A>
  <INPUT TYPE="hidden" NAME="referral_custnum" VALUE="<%= $cust_main->referral_custnum %>">

<% } elsif ( ! $conf->exists('disable_customer_referrals') ) { %>

  <BR><BR>Referring customer number: 
  <INPUT TYPE="text" NAME="referral_custnum" VALUE="">

<% } else { %>

  <INPUT TYPE="hidden" NAME="referral_custnum" VALUE="">

<% } %>

<!-- contact info -->

<BR><BR>
Billing address
<%= include('cust_main/contact.html', $cust_main, '', 'bill_changed(this)', '' ) %>

<!-- service address -->

<% if ( defined $cust_main->dbdef_table->column('ship_last') ) { %>

<SCRIPT>
function bill_changed(what) {
  if ( what.form.same.checked ) {
<% for (qw( last first company address1 address2 city zip daytime night fax )) { %>
    what.form.ship_<%=$_%>.value = what.form.<%=$_%>.value;
<% } %>

    what.form.ship_country.selectedIndex = what.form.country.selectedIndex;
    function fix_ship_state() {
      what.form.ship_state.selectedIndex = what.form.state.selectedIndex;
    }
    ship_country_changed(what.form.ship_country, fix_ship_state );

    function fix_ship_county() {
      what.form.ship_county.selectedIndex = what.form.county.selectedIndex;
    }
    ship_state_changed(what.form.ship_state, fix_ship_county );
  }
}
function samechanged(what) {
  if ( what.checked ) {
    bill_changed(what);
<% for (qw( last first company address1 address2 city county state zip country daytime night fax )) { %>
    what.form.ship_<%=$_%>.disabled = true;
    what.form.ship_<%=$_%>.style.backgroundColor = '#dddddd';
<% } %>
  } else {
<% for (qw( last first company address1 address2 city county state zip country daytime night fax )) { %>
    what.form.ship_<%=$_%>.disabled = false;
    what.form.ship_<%=$_%>.style.backgroundColor = '#ffffff';
<% } %>
  }
}
</SCRIPT>

<%
  my $checked = '';
  my $disabled = '';
  my $disabledselect = '';
  unless ( $cust_main->ship_last && $same ne 'Y' ) {
    $checked = 'CHECKED';
    $disabled = 'DISABLED style="background-color: #dddddd"';
    foreach (
      qw( last first company address1 address2 city county state zip country
          daytime night fax )
    ) {
      $cust_main->set("ship_$_", $cust_main->get($_) );
    }
  }
%>

<BR>
Service address 
(<INPUT TYPE="checkbox" NAME="same" VALUE="Y" onClick="samechanged(this)" <%=$checked%>>same as billing address)
<%= include('cust_main/contact.html', $cust_main, 'ship_', '', $disabled ) %>

<% } %>

<!-- billing info -->

<%= include( 'cust_main/billing.html', $cust_main,
               'invoicing_list' => \@invoicing_list,
           )
%>

<SCRIPT>
function bottomfixup(what) {

  var topvars = new Array(
    'custnum', 'agentnum', 'refnum', 'referral_custnum',

    'last', 'first', 'ss', 'company',
    'address1', 'address2', 'city',
    'county', 'state', 'zip', 'country',
    'daytime', 'night', 'fax',

    'same',

    'ship_last', 'ship_first', 'ship_company',
    'ship_address1', 'ship_address2', 'ship_city',
    'ship_county', 'ship_state', 'ship_zip', 'ship_country',
    'ship_daytime','ship_night', 'ship_fax',

    'select' // XXX key
  );

  var layervars = new Array(
    'payauto',
    'payinfo', 'payinfo1', 'payinfo2',
    'payname', 'exp_month', 'exp_year', 'paycvv',
    'paystart_month', 'paystart_year', 'payissue',
    'payip',
    'paid'
  );

  var billing_bottomvars = new Array(
    'tax',
    'invoicing_list', 'invoicing_list_POST', 'invoicing_list_FAX'
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

<FORM ACTION="<%= popurl(1) %>process/cust_main.cgi" METHOD=POST NAME="bottomform" onSubmit="document.bottomform.submit.disabled=true; bottomfixup(this.form);" STYLE="margin-top: 0; margin-bottom: 0">

<% foreach my $hidden (
     'custnum', 'agentnum', 'refnum', 'referral_custnum',
     'last', 'first', 'ss', 'company',
     'address1', 'address2', 'city',
     'county', 'state', 'zip', 'country',
     'daytime', 'night', 'fax',
     
     'same',
     
     'ship_last', 'ship_first', 'ship_company',
     'ship_address1', 'ship_address2', 'ship_city',
     'ship_county', 'ship_state', 'ship_zip', 'ship_country',
     'ship_daytime','ship_night', 'ship_fax',
     
     'select', #XXX key

     'payauto',
     'payinfo', 'payinfo1', 'payinfo2',
     'payname', 'exp_month', 'exp_year', 'paycvv',
     'paystart_month', 'paystart_year', 'payissue',
     'payip',
     'paid',
     
     'tax',
     'invoicing_list', 'invoicing_list_POST', 'invoicing_list_FAX'
   ) {
%>
  <INPUT TYPE="hidden" NAME="<%= $hidden %>" VALUE="">
<% } %>

<BR>Comments
<%= &ntable("#cccccc") %>
  <TR>
    <TD>
      <TEXTAREA COLS=80 ROWS=5 WRAP="HARD" NAME="comments"><%= $cust_main->comments %></TEXTAREA>
    </TD>
  </TR>
</TABLE>

<%

unless ( $custnum ) {
  # pry the wrong place for this logic.  also pretty expensive
  #use FS::part_pkg;

  #false laziness, copied from FS::cust_pkg::order
  my $pkgpart;
  if ( scalar(@agents) == 1 ) {
    # $pkgpart->{PKGPART} is true iff $custnum may purchase PKGPART
    my($agent)=qsearchs('agent',{'agentnum'=> $agentnum });
    $pkgpart = $agent->pkgpart_hashref;
  } else {
    #can't know (agent not chosen), so, allow all
    my %typenum;
    foreach my $agent ( @agents ) {
      next if $typenum{$agent->typenum}++;
      #fixed in 5.004_05 #$pkgpart->{$_}++ foreach keys %{ $agent->pkgpart_hashref }
      foreach ( keys %{ $agent->pkgpart_hashref } ) { $pkgpart->{$_}++; } #5.004_04 workaround
    }
  }
  #eslaf

  my @part_pkg = grep { $_->svcpart('svc_acct') && $pkgpart->{ $_->pkgpart } }
    qsearch( 'part_pkg', { 'disabled' => '' } );

  if ( @part_pkg ) {

#    print "<BR><BR>First package", &itable("#cccccc", "0 ALIGN=LEFT"),
#apiabuse & undesirable wrapping
    print "<BR>First package", &ntable("#cccccc"),
          qq!<TR><TD COLSPAN=2><SELECT NAME="pkgpart_svcpart">!;

    print qq!<OPTION VALUE="">(none)!;

    foreach my $part_pkg ( @part_pkg ) {
      print qq!<OPTION VALUE="!,
#              $part_pkg->pkgpart. "_". $pkgpart{ $part_pkg->pkgpart }, '"';
              $part_pkg->pkgpart. "_". $part_pkg->svcpart('svc_acct'), '"';
      print " SELECTED" if $saved_pkgpart && ( $part_pkg->pkgpart == $saved_pkgpart );
      print ">", $part_pkg->pkg, " - ", $part_pkg->comment;
    }
    print "</SELECT></TD></TR>";

    #false laziness: (mostly) copied from edit/svc_acct.cgi
    #$ulen = $svc_acct->dbdef_table->column('username')->length;
    my $ulen = dbdef->table('svc_acct')->column('username')->length;
    my $ulen2 = $ulen+2;
    my $passwordmax = $conf->config('passwordmax') || 8;
    my $pmax2 = $passwordmax + 2;
    print <<END;
<TR><TD ALIGN="right">Username</TD>
<TD><INPUT TYPE="text" NAME="username" VALUE="$username" SIZE=$ulen2 MAXLENGTH=$ulen></TD></TR>
<TR><TD ALIGN="right">Password</TD>
<TD><INPUT TYPE="text" NAME="_password" VALUE="$password" SIZE=$pmax2 MAXLENGTH=$passwordmax>
(blank to generate)</TD></TR>
END

    print '<TR><TD ALIGN="right">Access number</TD><TD>'
          .
          &FS::svc_acct_pop::popselector($popnum).
          '</TD></TR></TABLE>'
          ;
  }
}

my $otaker = $cust_main->otaker;
print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!,
      qq!<BR><INPUT TYPE="submit" NAME="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!"><BR>!,
      "</FORM></DIV></BODY></HTML>",
;

%>
