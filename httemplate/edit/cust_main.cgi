<!-- mason kludge -->
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

<FORM ACTION="<%= popurl(1) %>process/cust_main.cgi" METHOD=POST NAME="form1" onSubmit="document.form1.submit.disabled=true">
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

<%

# (referral and referring customer still need to be "template"ized)

#referral

my $refnum = $cust_main->refnum || $conf->config('referraldefault') || 0;
if ( $custnum && ! $conf->exists('editreferrals') ) {
  print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$refnum">!;
} else {
  my(@referrals) = qsearch('part_referral',{});
  if ( scalar(@referrals) == 0 ) {
    eidiot "You have not created any advertising sources.  You must create at least one advertising source before adding a customer.  Go to ". popurl(2). "browse/part_referral.cgi and create one or more advertising sources.";
  } elsif ( scalar(@referrals) == 1 ) {
    $refnum ||= $referrals[0]->refnum;
    print qq!<INPUT TYPE="hidden" NAME="refnum" VALUE="$refnum">!;
  } else {
    print qq!<BR><BR>${r}Advertising source <SELECT NAME="refnum" SIZE="1">!;
    print "<OPTION> " unless $refnum;
    my($referral);
    foreach $referral (sort {
      $a->refnum <=> $b->refnum;
    } @referrals) {
      print "<OPTION" . " SELECTED"x($referral->refnum==$refnum),
      ">", $referral->refnum, ": ", $referral->referral;
    }
    print "</SELECT>";
  }
}

#referring customer

#print qq!<BR><BR>Referring Customer: !;
my $referring_cust_main = '';
if ( $cust_main->referral_custnum
     and $referring_cust_main =
           qsearchs('cust_main', { custnum => $cust_main->referral_custnum } )
) {
  print '<BR><BR>Referring Customer: <A HREF="'. popurl(1). '/cust_main.cgi?'.
        $cust_main->referral_custnum. '">'.
        $cust_main->referral_custnum. ': '.
        ( $referring_cust_main->company
          || $referring_cust_main->last. ', '. $referring_cust_main->first ).
        '</A><INPUT TYPE="hidden" NAME="referral_custnum" VALUE="'.
        $cust_main->referral_custnum. '">';
} elsif ( ! $conf->exists('disable_customer_referrals') ) {
  print '<BR><BR>Referring customer number: <INPUT TYPE="text" NAME="referral_custnum" VALUE="">';
} else {
  print '<INPUT TYPE="hidden" NAME="referral_custnum" VALUE="">';
}

%>

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
    ship_country_changed(what.form.ship_country);
    what.form.ship_state.selectedIndex = what.form.state.selectedIndex;
    ship_state_changed(what.form.ship_state);
    what.form.ship_county.selectedIndex = what.form.county.selectedIndex;
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
  unless ( $cust_main->ship_last && $cgi->param('same') ne 'Y' ) {
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

<%
# billing info

sub expselect {
  my $prefix = shift;
  my( $m, $y ) = (0, 0);
  if ( scalar(@_) ) {
    my $date = shift || '01-2000';
    if ( $date  =~ /^(\d{4})-(\d{1,2})-\d{1,2}$/ ) { #PostgreSQL date format
      ( $m, $y ) = ( $2, $1 );
    } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
      ( $m, $y ) = ( $1, $3 );
    } else {
      die "unrecognized expiration date format: $date";
    }
  }

  my $return = qq!<SELECT NAME="$prefix!. qq!_month" SIZE="1">!;
  for ( 1 .. 12 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $m;
    $return .= ">$_";
  }
  $return .= qq!</SELECT>/<SELECT NAME="$prefix!. qq!_year" SIZE="1">!;
  my @t = localtime;
  my $thisYear = $t[5] + 1900;
  for ( ($thisYear > $y && $y > 0 ? $y : $thisYear) .. 2037 ) {
    $return .= "<OPTION";
    $return .= " SELECTED" if $_ == $y;
    $return .= ">$_";
  }
  $return .= "</SELECT>";

  $return;
}

my $payby_default = $conf->config('payby-default');

if ( $payby_default eq 'HIDE' ) {

  $cust_main->payby('BILL') unless $cust_main->payby;

  foreach my $field (qw( tax payby )) {
    print qq!<INPUT TYPE="hidden" NAME="$field" VALUE="!.
          $cust_main->getfield($field). '">';
  }

  print qq!<INPUT TYPE="hidden" NAME="invoicing_list" VALUE="!.
        join(', ', $cust_main->invoicing_list). '">';

  foreach my $payby (qw( CARD DCRD CHEK DCHK LECB BILL COMP )) {
    foreach my $field (qw( payinfo payname )) {
      print qq!<INPUT TYPE="hidden" NAME="${payby}_$field" VALUE="!.
            $cust_main->getfield($field). '">';
    }

    #false laziness w/expselect
    my( $m, $y );
    my $date = $cust_main->paydate || '12-2037';
    if ( $date  =~ /^(\d{4})-(\d{1,2})-\d{1,2}$/ ) { #PostgreSQL date format
      ( $m, $y ) = ( $2, $1 );
    } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
      ( $m, $y ) = ( $1, $3 );
    } else {
      die "unrecognized expiration date format: $date";
    }

    print qq!<INPUT TYPE="hidden" NAME="${payby}_month" VALUE="$m">!.
          qq!<INPUT TYPE="hidden" NAME="${payby}_year"  VALUE="$y">!;

  }

} else {

  print "<BR>Billing information", &itable("#cccccc"),
        qq!<TR><TD><INPUT TYPE="checkbox" NAME="tax" VALUE="Y"!;
  print qq! CHECKED! if $cust_main->tax eq "Y";
  print qq!>Tax Exempt</TD></TR><TR><TD>!.
        qq!<INPUT TYPE="checkbox" NAME="invoicing_list_POST" VALUE="POST"!;

  #my @invoicing_list = $cust_main->invoicing_list;
  print qq! CHECKED!
    if ( ! @invoicing_list && ! $conf->exists('disablepostalinvoicedefault') )
       || grep { $_ eq 'POST' } @invoicing_list;
  print qq!>Postal mail invoice</TD></TR><TR><TD>!;
  print qq!<INPUT TYPE="checkbox" NAME="invoicing_list_FAX" VALUE="FAX"!;
  print qq! CHECKED! if (grep { $_ eq 'FAX' } @invoicing_list);
  print qq!>FAX invoice</TD></TR>!;
  my $invoicing_list = join(', ', grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list );
  print qq!<TR><TD>Email invoice <INPUT TYPE="text" NAME="invoicing_list" VALUE="$invoicing_list"></TD></TR>!;

  print "<TR><TD>Billing type</TD></TR>",
        "</TABLE>", '<SCRIPT>
                       var mywindow = -1;
                       function myopen(filename,windowname,properties) {
                         myclose();
                         mywindow = window.open(filename,windowname,properties);
                       }
                       function myclose() {
                         if ( mywindow != -1 )
                           mywindow.close();
                         mywindow = -1;
                       }
                       var achwindow = -1;
                       function achopen(filename,windowname,properties) {
                         achclose();
                         achwindow = window.open(filename,windowname,properties);
                       }
                       function achclose() {
                         if ( achwindow != -1 )
                           achwindow.close();
                         achwindow = -1;
                       }
                     </SCRIPT>',
        &table("#cccccc"), "<TR>";

  my($payinfo, $payname)=(
    $cust_main->payinfo,
    $cust_main->payname,
  );

  my %payby = (
    'CARD' => qq!Credit card (automatic)<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD"). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
    'DCRD' => qq!Credit card (on-demand)<BR>${r}<INPUT TYPE="text" NAME="DCRD_payinfo" VALUE="" MAXLENGTH=19><BR>${r}Exp !. expselect("DCRD"). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="DCRD_payname" VALUE="">!,
    'CHEK' => qq!Electronic check (automatic)<BR>${r}Account number <INPUT TYPE="text" NAME="CHEK_payinfo1" VALUE=""><BR>${r}ABA/Routing number <INPUT TYPE="text" NAME="CHEK_payinfo2" VALUE="" SIZE=10 MAXLENGTH=9> (<A HREF="javascript:achopen('../docs/ach.html','ach','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=384,height=256')">help</A>)<INPUT TYPE="hidden" NAME="CHEK_month" VALUE="12"><INPUT TYPE="hidden" NAME="CHEK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="CHEK_payname" VALUE="">!,
    'DCHK' => qq!Electronic check (on-demand)<BR>${r}Account number <INPUT TYPE="text" NAME="DCHK_payinfo1" VALUE=""><BR>${r}ABA/Routing number <INPUT TYPE="text" NAME="DCHK_payinfo2" VALUE="" SIZE=10 MAXLENGTH=9> (<A HREF="javascript:achopen('../docs/ach.html','ach','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=384,height=256')">help</A>)<INPUT TYPE="hidden" NAME="DCHK_month" VALUE="12"><INPUT TYPE="hidden" NAME="DCHK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="DCHK_payname" VALUE="">!,
    'LECB' => qq!Phone bill billing<BR>${r}Phone number <INPUT TYPE="text" BANE="LECB_payinfo" VALUE="" MAXLENGTH=15 SIZE=16><INPUT TYPE="hidden" NAME="LECB_month" VALUE="12"><INPUT TYPE="hidden" NAME="LECB_year" VALUE="2037"><INPUT TYPE="hidden" NAME="LECB_payname" VALUE="">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR><INPUT TYPE="hidden" NAME="BILL_month" VALUE="12"><INPUT TYPE="hidden" NAME="BILL_year" VALUE="2037">Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR>${r}Exp !. expselect("COMP"),
);

  if ( $cust_main->dbdef_table->column('paycvv') ) {
    foreach my $payby ( grep { exists $payby{$_} } qw(CARD DCRD) ) { #1.4/1.5 bs
      $payby{$payby} .= qq!<BR>CVV2&nbsp;(<A HREF="javascript:myopen('../docs/cvv2.html','cvv2','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=480,height=288')">help</A>)&nbsp;<INPUT TYPE="text" NAME=${payby}_paycvv VALUE="" SIZE=4 MAXLENGTH=4>!;
    }
  }

  my( $account, $aba ) = split('@', $payinfo);

  my %paybychecked = (
    'CARD' => qq!Credit card (automatic)<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD", $cust_main->paydate). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
    'DCRD' => qq!Credit card (on-demand)<BR>${r}<INPUT TYPE="text" NAME="DCRD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>${r}Exp !. expselect("DCRD", $cust_main->paydate). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="DCRD_payname" VALUE="$payname">!,
    'CHEK' => qq!Electronic check (automatic)<BR>${r}Account number <INPUT TYPE="text" NAME="CHEK_payinfo1" VALUE="$account"><BR>${r}ABA/Routing number <INPUT TYPE="text" NAME="CHEK_payinfo2" VALUE="$aba" SIZE=10 MAXLENGTH=9> (<A HREF="javascript:achopen('../docs/ach.html','ach','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=384,height=256')">help</A>)<INPUT TYPE="hidden" NAME="CHEK_month" VALUE="12"><INPUT TYPE="hidden" NAME="CHEK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="CHEK_payname" VALUE="$payname">!,
    'DCHK' => qq!Electronic check (on-demand)<BR>${r}Account number <INPUT TYPE="text" NAME="DCHK_payinfo1" VALUE="$account"><BR>${r}ABA/Routing number <INPUT TYPE="text" NAME="DCHK_payinfo2" VALUE="$aba" SIZE=10 MAXLENGTH=9> (<A HREF="javascript:achopen('../docs/ach.html','ach','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=384,height=256')">help</A>)<INPUT TYPE="hidden" NAME="DCHK_month" VALUE="12"><INPUT TYPE="hidden" NAME="DCHK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="DCHK_payname" VALUE="$payname">!,
    'LECB' => qq!Phone bill billing<BR>${r}Phone number <INPUT TYPE="text" BANE="LECB_payinfo" VALUE="$payinfo" MAXLENGTH=15 SIZE=16><INPUT TYPE="hidden" NAME="LECB_month" VALUE="12"><INPUT TYPE="hidden" NAME="LECB_year" VALUE="2037"><INPUT TYPE="hidden" NAME="LECB_payname" VALUE="">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR><INPUT TYPE="hidden" NAME="BILL_month" VALUE="12"><INPUT TYPE="hidden" NAME="BILL_year" VALUE="2037">Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("COMP", $cust_main->paydate),
);

  if ( $cust_main->dbdef_table->column('paycvv') ) {
    my $paycvv = $cust_main->paycvv;

    foreach my $payby ( grep { exists $payby{$_} } qw(CARD DCRD) ) { #1.4/1.5 bs
      $paybychecked{$payby} .= qq!<BR>CVV2&nbsp;(<A HREF="javascript:myopen('../docs/cvv2.html','cvv2','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,copyhistory=no,width=480,height=288')">help</A>)&nbsp;<INPUT TYPE="text" NAME=${payby}_paycvv VALUE="$paycvv" SIZE=4 MAXLENGTH=4>!;
    }
  }


  $cust_main->payby($payby_default) unless $cust_main->payby;
  for (qw(CARD DCRD CHEK DCHK LECB BILL COMP)) {
    print qq!<TD VALIGN=TOP><INPUT TYPE="radio" NAME="payby" VALUE="$_"!;
    if ($cust_main->payby eq "$_") {
      print qq! CHECKED> $paybychecked{$_}</TD>!;
    } else {
      print qq!> $payby{$_}</TD>!;
    }
  }

  print "</TR></TABLE>$r required fields for each billing type";

}

if ( defined $cust_main->dbdef_table->column('comments') ) {
    print "<BR><BR>Comments", &itable("#cccccc"),
          qq!<TR><TD><TEXTAREA COLS=80 ROWS=5 WRAP="HARD" NAME="comments">!,
          $cust_main->comments, "</TEXTAREA>",
          "</TD></TR></TABLE>";
}

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
    print "<BR><BR>First package", &itable("#cccccc"),
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

    print '<TR><TD ALIGN="right">Access number</TD><TD WIDTH="100%">'
          .
          &FS::svc_acct_pop::popselector($popnum).
          '</TD></TR></TABLE>'
          ;
  }
}

my $otaker = $cust_main->otaker;
print qq!<INPUT TYPE="hidden" NAME="otaker" VALUE="$otaker">!,
      qq!<BR><INPUT NAME="submit" TYPE="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!">!,
      "</FORM></BODY></HTML>",
;

%>
