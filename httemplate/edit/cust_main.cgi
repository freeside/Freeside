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
} elsif ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum=$1;
  $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  $saved_pkgpart = 0;
  $username = '';
  $password = '';
  $popnum = 0;
} else {
  $custnum='';
  $cust_main = new FS::cust_main ( {} );
  $cust_main->otaker( &getotaker );
  $cust_main->referral_custnum( $cgi->param('referral_custnum') );
  $saved_pkgpart = 0;
  $username = '';
  $password = '';
  $popnum = 0;
}
$cgi->delete_all();
my $action = $custnum ? 'Edit' : 'Add';

# top

my $p1 = popurl(1);
print header("Customer $action", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $error, "</FONT>"
  if $error;

print qq!<FORM ACTION="${p1}process/cust_main.cgi" METHOD=POST NAME="form1">!,
      qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!,
      qq!Customer # !, ( $custnum ? "<B>$custnum</B>" : " (NEW)" ),
      
;

# agent

my $r = qq!<font color="#ff0000">*</font>&nbsp;!;

my @agents = qsearch( 'agent', {} );
#die "No agents created!" unless @agents;
eidiot "You have not created any agents.  You must create at least one agent before adding a customer.  Go to ". popurl(2). "browse/agent.cgi and create one or more agents." unless @agents;
my $agentnum = $cust_main->agentnum || $agents[0]->agentnum; #default to first
if ( scalar(@agents) == 1 ) {
  print qq!<INPUT TYPE="hidden" NAME="agentnum" VALUE="$agentnum">!;
} else {
  print qq!<BR><BR>${r}Agent <SELECT NAME="agentnum" SIZE="1">!;
  my $agent;
  foreach $agent (sort {
    $a->agent cmp $b->agent;
  } @agents) {
      print '<OPTION VALUE="', $agent->agentnum, '"',
      " SELECTED"x($agent->agentnum==$agentnum),
      ">". $agent->agent;
      #">", $agent->agentnum,": ", $agent->agent;
  }
  print "</SELECT>";
}

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
if ( $cust_main->referral_custnum ) {
  my $referring_cust_main =
    qsearchs('cust_main', { custnum => $cust_main->referral_custnum } );
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

# contact info

my($last,$first,$ss,$company,$address1,$address2,$city,$zip)=(
  $cust_main->last,
  $cust_main->first,
  $cust_main->ss,
  $cust_main->company,
  $cust_main->address1,
  $cust_main->address2,
  $cust_main->city,
  $cust_main->zip,
);

print "<BR><BR>Billing address", &itable("#cccccc"), <<END;
<TR><TH ALIGN="right">${r}Contact&nbsp;name<BR>(last,&nbsp;first)</TH><TD COLSPAN=3>
END

print <<END;
<INPUT TYPE="text" NAME="last" VALUE="$last"> , 
<INPUT TYPE="text" NAME="first" VALUE="$first">
</TD>
END

if ( $conf->exists('show_ss') ) {
  print qq!<TD ALIGN="right">SS#</TD><TD><INPUT TYPE="text" NAME="ss" VALUE="$ss" SIZE=11></TD>!;
} else {
  print qq!<TD><INPUT TYPE="hidden" NAME="ss" VALUE="$ss"></TD>!;
}

print <<END;
</TR>
<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="company" VALUE="$company" SIZE=70></TD></TR>
<TR><TH ALIGN="right">${r}Address</TH><TD COLSPAN=5><INPUT TYPE="text" NAME="address1" VALUE="$address1" SIZE=70></TD></TR>
<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="address2" VALUE="$address2" SIZE=70></TD></TR>
<TR><TH ALIGN="right">${r}City</TH><TD><INPUT TYPE="text" NAME="city" VALUE="$city"></TD><TH ALIGN="right">${r}State</TH><TD>
END

#false laziness with ship state
my $countrydefault = $conf->config('countrydefault') || 'US';
$cust_main->country( $countrydefault ) unless $cust_main->country;

$cust_main->state( $conf->config('statedefault') || 'CA' )
  unless $cust_main->state || $cust_main->country ne 'US';

my($county_html, $state_html, $country_html) =
  FS::cust_main_county::regionselector( $cust_main->county,
                                        $cust_main->state,
                                        $cust_main->country );

print "$county_html $state_html";

print qq!</TD><TH>${r}Zip</TH><TD><INPUT TYPE="text" NAME="zip" VALUE="$zip" SIZE=10></TD></TR>!;

my($daytime,$night,$fax)=(
  $cust_main->daytime,
  $cust_main->night,
  $cust_main->fax,
);

my $daytime_label = gettext('daytime') || 'Day Phone';
my $night_label = gettext('night') || 'Night Phone';

print <<END;
<TR><TH ALIGN="right">${r}Country</TH><TD>$country_html</TD></TR>
<TR><TD ALIGN="right">$daytime_label</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="daytime" VALUE="$daytime" SIZE=18></TD></TR>
<TR><TD ALIGN="right">$night_label</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="night" VALUE="$night" SIZE=18></TD></TR>
<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="fax" VALUE="$fax" SIZE=12></TD></TR>
END

print "</TABLE>${r}required fields<BR>";

# service address

if ( defined $cust_main->dbdef_table->column('ship_last') ) {

  print "\n", <<END;
  <SCRIPT>
  function changed(what) {
    what.form.same.checked = false;
  }
  function samechanged(what) {
    if ( what.checked ) {
END
print "      what.form.ship_$_.value = what.form.$_.value;\n"
  for (qw( last first company address1 address2 city zip daytime night fax ));
print <<END;
      what.form.ship_country.selectedIndex = what.form.country.selectedIndex;
      ship_country_changed(what.form.ship_country);
      what.form.ship_state.selectedIndex = what.form.state.selectedIndex;
      ship_state_changed(what.form.ship_state);
      what.form.ship_county.selectedIndex = what.form.county.selectedIndex;
    }
  }
  </SCRIPT>
END

  print '<BR>Service address ',
        '(<INPUT TYPE="checkbox" NAME="same" VALUE="Y" onClick="samechanged(this)"';
  unless ( $cust_main->ship_last && $cgi->param('same') ne 'Y' ) {
    print ' CHECKED';
    foreach (
      qw( last first company address1 address2 city county state zip country
          daytime night fax )
    ) {
      $cust_main->set("ship_$_", $cust_main->get($_) );
    }
  }
  print '>same as billing address)<BR>';

  my($ship_last,$ship_first,$ship_company,$ship_address1,$ship_address2,$ship_city,$ship_zip)=(
    $cust_main->ship_last,
    $cust_main->ship_first,
    $cust_main->ship_company,
    $cust_main->ship_address1,
    $cust_main->ship_address2,
    $cust_main->ship_city,
    $cust_main->ship_zip,
  );

  print &itable("#cccccc"), <<END;
  <TR><TH ALIGN="right">${r}Contact&nbsp;name<BR>(last,&nbsp;first)</TH><TD COLSPAN=5>
END

  print <<END;
  <INPUT TYPE="text" NAME="ship_last" VALUE="$ship_last" onChange="changed(this)"> , 
  <INPUT TYPE="text" NAME="ship_first" VALUE="$ship_first" onChange="changed(this)">
END

  print <<END;
  </TD></TR>
  <TR><TD ALIGN="right">Company</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_company" VALUE="$ship_company" SIZE=70 onChange="changed(this)"></TD></TR>
  <TR><TH ALIGN="right">${r}Address</TH><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_address1" VALUE="$ship_address1" SIZE=70 onChange="changed(this)"></TD></TR>
  <TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_address2" VALUE="$ship_address2" SIZE=70 onChange="changed(this)"></TD></TR>
  <TR><TH ALIGN="right">${r}City</TH><TD><INPUT TYPE="text" NAME="ship_city" VALUE="$ship_city" onChange="changed(this)"></TD><TH ALIGN="right">${r}State</TH><TD>
END

  #false laziness with regular state
  $cust_main->ship_country( $countrydefault ) unless $cust_main->ship_country;

  $cust_main->ship_state( $conf->config('statedefault') || 'CA' )
    unless $cust_main->ship_state || $cust_main->ship_country ne 'US';

  my($ship_county_html, $ship_state_html, $ship_country_html) =
    FS::cust_main_county::regionselector( $cust_main->ship_county,
                                          $cust_main->ship_state,
                                          $cust_main->ship_country,
                                          'ship_',
                                          'changed(this)', );

  print "$ship_county_html $ship_state_html";

  print qq!</TD><TH>${r}Zip</TH><TD><INPUT TYPE="text" NAME="ship_zip" VALUE="$ship_zip" SIZE=10 onChange="changed(this)"></TD></TR>!;

  my($ship_daytime,$ship_night,$ship_fax)=(
    $cust_main->ship_daytime,
    $cust_main->ship_night,
    $cust_main->ship_fax,
  );

  print <<END;
  <TR><TH ALIGN="right">${r}Country</TH><TD>$ship_country_html</TD></TR>
  <TR><TD ALIGN="right">$daytime_label</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_daytime" VALUE="$ship_daytime" SIZE=18 onChange="changed(this)"></TD></TR>
  <TR><TD ALIGN="right">$night_label</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_night" VALUE="$ship_night" SIZE=18 onChange="changed(this)"></TD></TR>
  <TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5><INPUT TYPE="text" NAME="ship_fax" VALUE="$ship_fax" SIZE=12 onChange="changed(this)"></TD></TR>
END

  print "</TABLE>${r}required fields<BR>";

}

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
  for ( 2001 .. 2037 ) {
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

  foreach my $payby (qw( CARD CHEK BILL COMP )) {
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

  my @invoicing_list = $cust_main->invoicing_list;
  print qq! CHECKED!
    if ( ! @invoicing_list && ! $conf->exists('disablepostalinvoicedefault') )
       || grep { $_ eq 'POST' } @invoicing_list;
  print qq!>Postal mail invoice</TD></TR>!;
  my $invoicing_list = join(', ', grep { $_ ne 'POST' } @invoicing_list );
  print qq!<TR><TD>Email invoice <INPUT TYPE="text" NAME="invoicing_list" VALUE="$invoicing_list"></TD></TR>!;

  print "<TR><TD>Billing type</TD></TR>",
        "</TABLE>",
        &table("#cccccc"), "<TR>";

  my($payinfo, $payname)=(
    $cust_main->payinfo,
    $cust_main->payname,
  );

  my %payby = (
    'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD"). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="">!,
    'CHEK' => qq!Electronic check<BR>${r}Account number <INPUT TYPE="text" NAME="CHEK_payinfo1" VALUE="" MAXLENGTH=10><BR>${r}ABA/Routing code <INPUT TYPE="text" NAME="CHEK_payinfo2" VALUE="" SIZE=10 MAXLENGTH=9><INPUT TYPE="hidden" NAME="CHEK_month" VALUE="12"><INPUT TYPE="hidden" NAME="CHEK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="CHEK_payname" VALUE="">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE=""><BR><INPUT TYPE="hidden" NAME="BILL_month" VALUE="12"><INPUT TYPE="hidden" NAME="BILL_year" VALUE="2037">Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE=""><BR>${r}Exp !. expselect("COMP"),
);

  my( $account, $aba ) = split('@', $payinfo);

  my %paybychecked = (
    'CARD' => qq!Credit card<BR>${r}<INPUT TYPE="text" NAME="CARD_payinfo" VALUE="$payinfo" MAXLENGTH=19><BR>${r}Exp !. expselect("CARD", $cust_main->paydate). qq!<BR>${r}Name on card<BR><INPUT TYPE="text" NAME="CARD_payname" VALUE="$payname">!,
    'CHEK' => qq!Electronic check<BR>${r}Account number <INPUT TYPE="text" NAME="CHEK_payinfo1" VALUE="$account" MAXLENGTH=10><BR>${r}ABA/Routing code <INPUT TYPE="text" NAME="CHEK_payinfo2" VALUE="$aba" SIZE=10 MAXLENGTH=9><INPUT TYPE="hidden" NAME="CHEK_month" VALUE="12"><INPUT TYPE="hidden" NAME="CHEK_year" VALUE="2037"><BR>${r}Bank name <INPUT TYPE="text" NAME="CHEK_payname" VALUE="$payname">!,
    'BILL' => qq!Billing<BR>P.O. <INPUT TYPE="text" NAME="BILL_payinfo" VALUE="$payinfo"><BR><INPUT TYPE="hidden" NAME="BILL_month" VALUE="12"><INPUT TYPE="hidden" NAME="BILL_year" VALUE="2037">Attention<BR><INPUT TYPE="text" NAME="BILL_payname" VALUE="$payname">!,
    'COMP' => qq!Complimentary<BR>${r}Approved by<INPUT TYPE="text" NAME="COMP_payinfo" VALUE="$payinfo"><BR>${r}Exp !. expselect("COMP", $cust_main->paydate),
);

  $cust_main->payby($payby_default) unless $cust_main->payby;
  for (qw(CARD CHEK BILL COMP)) {
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
              $part_pkg->pkgpart. "_". $part_pkg->svcpart, '"';
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
      qq!<BR><INPUT TYPE="submit" VALUE="!,
      $custnum ?  "Apply Changes" : "Add Customer", qq!">!,
      "</FORM></BODY></HTML>",
;

%>
