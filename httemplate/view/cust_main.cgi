<!-- mason kludge -->
<%

my $conf = new FS::Conf;

#false laziness with view/cust_pkg.cgi, but i'm trying to make that go away so
my %uiview = ();
my %uiadd = ();
foreach my $part_svc ( qsearch('part_svc',{}) ) {
  $uiview{$part_svc->svcpart} = popurl(2). "view/". $part_svc->svcdb . ".cgi";
  $uiadd{$part_svc->svcpart}= popurl(2). "edit/". $part_svc->svcdb . ".cgi";
}

print header("Customer View", menubar(
  'Main Menu' => popurl(2)
));

print <<END;
<STYLE TYPE="text/css">
.package TH { font-size: medium }
.package TR { font-size: smaller }
.package .pkgnum { font-size: medium }
.package .provision { font-weight: bold }
</STYLE>
END

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my $custnum = $1;
my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;

print qq!<A HREF="${p}edit/cust_main.cgi?$custnum">Edit this customer</A>!;

print <<END;
<SCRIPT>
function cancel_areyousure(href) {
    if (confirm("Perminantly delete all services and cancel this customer?") == true)
        window.location.href = href;
}
</SCRIPT>
END

print qq! | <A HREF="javascript:cancel_areyousure('${p}misc/cust_main-cancel.cgi?$custnum')">!.
      'Cancel this customer</A>'
  if $cust_main->ncancelled_pkgs;

print qq! | <A HREF="${p}misc/delete-customer.cgi?$custnum">!.
      'Delete this customer</A>'
  if $conf->exists('deletecustomers');

unless ( $conf->exists('disable_customer_referrals') ) {
  print qq! | <A HREF="!, popurl(2),
        qq!edit/cust_main.cgi?referral_custnum=$custnum">!,
        qq!Refer a new customer</A>!;

  print qq! | <A HREF="!, popurl(2),
        qq!search/cust_main.cgi?referral_custnum=$custnum">!,
        qq!View this customer's referrals</A>!;
}

print '<BR><BR>';

my $signupurl = $conf->config('signupurl');
if ( $signupurl ) {
print "This customer's signup URL: ".
      "<a href=\"$signupurl?ref=$custnum\">$signupurl?ref=$custnum</a><BR><BR>";
}

print '<A NAME="cust_main"></A>';

print &itable(), '<TR>';

print '<TD VALIGN="top">';

  print "Billing address", &ntable("#cccccc"), "<TR><TD>",
        &ntable("#cccccc",2),
    '<TR><TD ALIGN="right">Contact&nbsp;name</TD>',
      '<TD COLSPAN=3 BGCOLOR="#ffffff">',
      $cust_main->last, ', ', $cust_main->first,
      '</TD>';
print '<TD ALIGN="right">SS#</TD><TD BGCOLOR="#ffffff">',
      $cust_main->ss || '&nbsp', '</TD>'
  if $conf->exists('show_ss');

print '</TR>',
    '<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
      $cust_main->company,
      '</TD></TR>',
    '<TR><TD ALIGN="right">Address</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
      $cust_main->address1,
      '</TD></TR>',
  ;
  print '<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->address2, '</TD></TR>'
    if $cust_main->address2;
  print '<TR><TD ALIGN="right">City</TD><TD BGCOLOR="#ffffff">',
          $cust_main->city,
          '</TD><TD ALIGN="right">State</TD><TD BGCOLOR="#ffffff">',
          $cust_main->state,
          '</TD><TD ALIGN="right">Zip</TD><TD BGCOLOR="#ffffff">',
          $cust_main->zip, '</TD></TR>',
        '<TR><TD ALIGN="right">Country</TD><TD BGCOLOR="#ffffff">',
          $cust_main->country,
          '</TD></TR>',
  ;
  my $daytime_label = FS::Msgcat::_gettext('daytime') || 'Day&nbsp;Phone';
  my $night_label = FS::Msgcat::_gettext('night') || 'Night&nbsp;Phone';
  print '<TR><TD ALIGN="right">'. $daytime_label.
          '</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->daytime || '&nbsp', '</TD></TR>',
        '<TR><TD ALIGN="right">'. $night_label. 
          '</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->night || '&nbsp', '</TD></TR>',
        '<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->fax || '&nbsp', '</TD></TR>',
        '</TABLE>', "</TD></TR></TABLE>"
  ;

  if ( defined $cust_main->dbdef_table->column('ship_last') ) {

    my $pre = $cust_main->ship_last ? 'ship_' : '';

    print "<BR>Service address", &ntable("#cccccc"), "<TR><TD>",
          &ntable("#cccccc",2),
      '<TR><TD ALIGN="right">Contact name</TD>',
        '<TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}last"), ', ', $cust_main->get("${pre}first"),
        '</TD></TR>',
      '<TR><TD ALIGN="right">Company</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}company"),
        '</TD></TR>',
      '<TR><TD ALIGN="right">Address</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
        $cust_main->get("${pre}address1"),
        '</TD></TR>',
    ;
    print '<TR><TD ALIGN="right">&nbsp;</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
          $cust_main->get("${pre}address2"), '</TD></TR>'
      if $cust_main->get("${pre}address2");
    print '<TR><TD ALIGN="right">City</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}city"),
            '</TD><TD ALIGN="right">State</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}state"),
            '</TD><TD ALIGN="right">Zip</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}zip"), '</TD></TR>',
          '<TR><TD ALIGN="right">Country</TD><TD BGCOLOR="#ffffff">',
            $cust_main->get("${pre}country"),
            '</TD></TR>',
    ;
    print '<TR><TD ALIGN="right">'. $daytime_label. '</TD>',
          '<TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}daytime") || '&nbsp', '</TD></TR>',
          '<TR><TD ALIGN="right">'. $night_label. '</TD>'.
          '<TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}night") || '&nbsp', '</TD></TR>',
          '<TR><TD ALIGN="right">Fax</TD><TD COLSPAN=5 BGCOLOR="#ffffff">',
            $cust_main->get("${pre}fax") || '&nbsp', '</TD></TR>',
          '</TABLE>', "</TD></TR></TABLE>"
    ;

  }

print '</TD>';

print '<TD VALIGN="top">';

  print &ntable("#cccccc"), "<TR><TD>", &ntable("#cccccc",2),
        '<TR><TD ALIGN="right">Customer&nbsp;number</TD><TD BGCOLOR="#ffffff">',
        $custnum, '</TD></TR>',
  ;

  my @agents = qsearch( 'agent', {} );
  my $agent;
  unless ( scalar(@agents) == 1 ) {
    $agent = qsearchs('agent',{ 'agentnum' => $cust_main->agentnum } );
    print '<TR><TD ALIGN="right">Agent</TD><TD BGCOLOR="#ffffff">',
        $agent->agentnum, ": ", $agent->agent, '</TD></TR>';
  } else {
    $agent = $agents[0];
  }
  my @referrals = qsearch( 'part_referral', {} );
  unless ( scalar(@referrals) == 1 ) {
    my $referral = qsearchs('part_referral', {
      'refnum' => $cust_main->refnum
    } );
    print '<TR><TD ALIGN="right">Advertising&nbsp;source</TD><TD BGCOLOR="#ffffff">',
          $referral->refnum, ": ", $referral->referral, '</TD></TR>';
  }
  print '<TR><TD ALIGN="right">Order taker</TD><TD BGCOLOR="#ffffff">',
    $cust_main->otaker, '</TD></TR>';

  print '<TR><TD ALIGN="right">Referring&nbsp;Customer</TD><TD BGCOLOR="#ffffff">';
  my $referring_cust_main = '';
  if ( $cust_main->referral_custnum
       && ( $referring_cust_main =
            qsearchs('cust_main', { custnum => $cust_main->referral_custnum } )
          )
     ) {
    print '<A HREF="'. popurl(1). 'cust_main.cgi?'.
          $cust_main->referral_custnum. '">'.
          $cust_main->referral_custnum. ': '.
          ( $referring_cust_main->company
              ? $referring_cust_main->company. ' ('.
                  $referring_cust_main->last. ', '. $referring_cust_main->first.
                  ')'
              : $referring_cust_main->last. ', '. $referring_cust_main->first
          ).
          '</A>';
  }
  print '</TD></TR>';

  print '</TABLE></TD></TR></TABLE>';

print '<BR>';

if ( $conf->config('payby-default') ne 'HIDE' ) {

  my @invoicing_list = $cust_main->invoicing_list;
  print "Billing information (",
       qq!<A HREF="!, popurl(2), qq!misc/bill.cgi?$custnum">!, "Bill now</A>)",
        &ntable("#cccccc"), "<TR><TD>", &ntable("#cccccc",2),
        '<TR><TD ALIGN="right">Tax&nbsp;exempt</TD><TD BGCOLOR="#ffffff">',
        $cust_main->tax ? 'yes' : 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Postal&nbsp;invoices</TD><TD BGCOLOR="#ffffff">',
        ( grep { $_ eq 'POST' } @invoicing_list ) ? 'yes' : 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Email&nbsp;invoices</TD><TD BGCOLOR="#ffffff">',
        join(', ', grep { $_ ne 'POST' } @invoicing_list ) || 'no',
        '</TD></TR>',
        '<TR><TD ALIGN="right">Billing&nbsp;type</TD><TD BGCOLOR="#ffffff">',
  ;

  if ( $cust_main->payby eq 'CARD' || $cust_main->payby eq 'DCRD' ) {
    my $payinfo = $cust_main->payinfo;
    $payinfo = 'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4));
    print 'Credit&nbsp;card&nbsp;',
          ( $cust_main->payby eq 'CARD' ? '(automatic)' : '(on-demand)' ),
          '</TD></TR>',
          '<TR><TD ALIGN="right">Card number</TD><TD BGCOLOR="#ffffff">',
          $payinfo, '</TD></TR>',
          '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
          '<TR><TD ALIGN="right">Name on card</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payname, '</TD></TR>'
    ;
  } elsif ( $cust_main->payby eq 'CHEK' || $cust_main->payby eq 'DCHK') {
    my( $account, $aba ) = split('@', $cust_main->payinfo );
    print 'Electronic&nbsp;check&nbsp;',
          ( $cust_main->payby eq 'CHEK' ? '(automatic)' : '(on-demand)' ),
          '</TD></TR>',
          '<TR><TD ALIGN="right">Account number</TD><TD BGCOLOR="#ffffff">',
          $account, '</TD></TR>',
          '<TR><TD ALIGN="right">ABA/Routing code</TD><TD BGCOLOR="#ffffff">',
          $aba, '</TD></TR>',
          '<TR><TD ALIGN="right">Bank name</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payname, '</TD></TR>'
    ;
  } elsif ( $cust_main->payby eq 'LECB' ) {
    $cust_main->payinfo =~ /^(\d{3})(\d{3})(\d{4})$/;
    my $payinfo = "$1-$2-$3";
    print 'Phone&nbsp;bill&nbsp;billing</TD></TR>',
          '<TR><TD ALIGN="right">Phone number</TD><TD BGCOLOR="#ffffff">',
          $payinfo, '</TD></TR>',
    ;
  } elsif ( $cust_main->payby eq 'BILL' ) {
    print 'Billing</TD></TR>';
    print '<TR><TD ALIGN="right">P.O. </TD><TD BGCOLOR="#ffffff">',
          $cust_main->payinfo, '</TD></TR>',
      if $cust_main->payinfo;
    print '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
          '<TR><TD ALIGN="right">Attention</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payname, '</TD></TR>',
    ;
  } elsif ( $cust_main->payby eq 'COMP' ) {
    print 'Complimentary</TD></TR>',
          '<TR><TD ALIGN="right">Authorized&nbsp;by</TD><TD BGCOLOR="#ffffff">',
          $cust_main->payinfo, '</TD></TR>',
          '<TR><TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">',
          $cust_main->paydate, '</TD></TR>',
    ;
  }

  print "</TABLE></TD></TR></TABLE>";

}

print '</TD></TR></TABLE>';

if ( defined $cust_main->dbdef_table->column('comments')
     && $cust_main->comments =~ /[^\s\n\r]/ )
{
  print "<BR>Comments". &ntable("#cccccc"). "<TR><TD>".
        &ntable("#cccccc",2).
        '<TR><TD BGCOLOR="#ffffff"><PRE>'.
        encode_entities($cust_main->comments).
        '</PRE></TD></TR></TABLE></TABLE>';
}

print '</TD></TR></TABLE>';

print '<BR>'.
  '<FORM ACTION="'.popurl(2).'edit/process/quick-cust_pkg.cgi" METHOD="POST">'.
  qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!.
  '<SELECT NAME="pkgpart"><OPTION> ';

foreach my $part_pkg (
  qsearch( 'part_pkg', { 'disabled' => '' }, '',
           ' AND 0 < ( SELECT COUNT(*) FROM type_pkgs '.
           '             WHERE typenum = '. $agent->typenum.
           '             AND type_pkgs.pkgpart = part_pkg.pkgpart )'
         )
) {
  print '<OPTION VALUE="'. $part_pkg->pkgpart. '">'. $part_pkg->pkg. ' - '.
        $part_pkg->comment;
}

print '</SELECT><INPUT TYPE="submit" VALUE="Order Package"></FORM><BR>';

if ( $conf->config('payby-default') ne 'HIDE' ) {

  print '<BR>'.
    qq!<FORM ACTION="${p}edit/process/quick-charge.cgi" METHOD="POST">!.
    qq!<INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">!.
    qq!Description:<INPUT TYPE="text" NAME="pkg">!.
    qq!&nbsp;Amount:<INPUT TYPE="text" NAME="amount" SIZE=6>!.
    qq!&nbsp;!;
  
  #false laziness w/ edit/part_pkg.cgi
  if ( $conf->exists('enable_taxclasses') ) {
    print '<SELECT NAME="taxclass">';
    my $sth = dbh->prepare('SELECT DISTINCT taxclass FROM cust_main_county')
      or die dbh->errstr;
    $sth->execute or die $sth->errstr;
    foreach my $taxclass ( map $_->[0], @{$sth->fetchall_arrayref} ) {
      print qq!<OPTION VALUE="$taxclass"!;
      #print ' SELECTED' if $taxclass eq $hashref->{taxclass};
      print qq!>$taxclass</OPTION>!;
    }
    print '</SELECT>';
  } else {
    print '<INPUT TYPE="hidden" NAME="taxclass" VALUE="">';
  }
  
  print qq!<INPUT TYPE="submit" VALUE="One-time charge"></FORM><BR>!;

}

print <<END;
<SCRIPT>
function cust_pkg_areyousure(href) {
    if (confirm("Permanently delete included services and cancel this package?") == true)
        window.location.href = href;
}
function svc_areyousure(href) {
    if (confirm("Permanently unprovision and delete this service?") == true)
        window.location.href = href;
}
</SCRIPT>
END

print qq!<BR><A NAME="cust_pkg">Packages</A> !,
#      qq!<BR>Click on package number to view/edit package.!,
      qq!( <A HREF="!, popurl(2), qq!edit/cust_pkg.cgi?$custnum">Order and cancel packages</A> (preserves services) )!,
;

#begin display packages

#get package info

my $packages = get_packages($cust_main, $conf);

if ( @$packages ) {
%>
<TABLE CLASS="package" BORDER=1 CELLSPACING=0 CELLPADDING=2 BORDERCOLOR="#999999">
<TR>
  <TH COLSPAN=2>Package</TH>
  <TH>Status</TH>
  <TH COLSPAN=2>Services</TH>
</TR>
<%
foreach my $pkg (sort pkgsort_pkgnum_cancel @$packages) {
  my $rowspan = 0;

  if ($pkg->{cancel}) {
    $rowspan = 0;
  } else {
    foreach my $svcpart (@{$pkg->{svcparts}}) {
      $rowspan += $svcpart->{count};
      $rowspan++ if ($svcpart->{count} < $svcpart->{quantity});
    }
  } 

%>
<!--pkgnum: <%=$pkg->{pkgnum}%>-->
<TR>
  <TD ROWSPAN=<%=$rowspan%> CLASS="pkgnum"><%=$pkg->{pkgnum}%></TD>
  <TD ROWSPAN=<%=$rowspan%>>
    <%=$pkg->{pkg}%> - <%=$pkg->{comment}%> (&nbsp;<%=pkg_details_link($pkg)%>&nbsp;)<BR>
<% unless ($pkg->{cancel}) { %>
    (&nbsp;<%=pkg_change_link($pkg)%>&nbsp;)
    (&nbsp;<%=pkg_dates_link($pkg)%>&nbsp;|&nbsp;<%=pkg_customize_link($pkg,$custnum)%>&nbsp;)
<% } %>
  </TD>
<%
  #foreach (qw(setup last_bill next_bill susp expire cancel)) {
  #  print qq!  <TD ROWSPAN=$rowspan>! . pkg_datestr($pkg,$_,$conf) . qq!</TD>\n!;
  #}
  print "<TD ROWSPAN=$rowspan>". &itable('');

  sub freq {

    #false laziness w/edit/part_pkg.cgi
    my %freq = ( #move this
      '1d' => 'daily',
      '1w' => 'weekly',
      '2w' => 'biweekly (every 2 weeks)',
      '1'  => 'monthly',
      '2'  => 'bimonthly (every 2 months)',
      '3'  => 'quarterly (every 3 months)',
      '6'  => 'semiannually (every 6 months)',
      '12' => 'annually',
      '24' => 'biannually (every 2 years)',
    );

    my $freq = shift;
    exists $freq{$freq} ? $freq{$freq} : "every&nbsp;$freq&nbsp;months";
  }

  #eomove

  if ( $pkg->{cancel} ) { #status: cancelled

    print '<TR><TD><FONT COLOR="#ff0000"><B>Cancelled&nbsp;</B></FONT></TD>'.
          '<TD>'. pkg_datestr($pkg,'cancel',$conf). '</TD></TR>';
    unless ( $pkg->{setup} ) {
      print '<TR><TD COLSPAN=2>Never billed</TD></TR>';
    } else {
      print "<TR><TD>Setup&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'setup',$conf). '</TD></TR>';
      print "<TR><TD>Last&nbsp;bill&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'last_bill',$conf). '</TD></TR>'
        if $pkg->{'last_bill'};
      print "<TR><TD>Suspended&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'susp',$conf). '</TD></TR>'
        if $pkg->{'susp'};
    }

  } else {

    if ( $pkg->{susp} ) { #status: suspended
      print '<TR><TD><FONT COLOR="#FF9900"><B>Suspended</B>&nbsp;</FONT></TD>'.
            '<TD>'. pkg_datestr($pkg,'susp',$conf). '</TD></TR>';
      unless ( $pkg->{setup} ) {
        print '<TR><TD COLSPAN=2>Never billed</TD></TR>';
      } else {
        print "<TR><TD>Setup&nbsp;</TD><TD>". 
              pkg_datestr($pkg, 'setup',$conf). '</TD></TR>';
      }
      print "<TR><TD>Last&nbsp;bill&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'last_bill',$conf). '</TD></TR>'
        if $pkg->{'last_bill'};
      # next bill ??
      print "<TR><TD>Expires&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'expire',$conf). '</TD></TR>'
        if $pkg->{'expire'};
      print '<TR><TD COLSPAN=2>(&nbsp;'. pkg_unsuspend_link($pkg).
            '&nbsp;|&nbsp;'. pkg_cancel_link($pkg). '&nbsp;)</TD></TR>';

    } else { #status: active

      unless ( $pkg->{setup} ) { #not setup

        print '<TR><TD COLSPAN=2>Not&nbsp;yet&nbsp;billed&nbsp;(';
        unless ( $pkg->{freq} ) {
          print 'one-time&nbsp;charge)</TD></TR>';
          print '<TR><TD COLSPAN=2>(&nbsp;'. pkg_cancel_link($pkg).
                '&nbsp;)</TD</TR>';
        } else {
          print 'billed&nbsp;'. freq($pkg->{freq}). ')</TD></TR>';
        }

      } else { #setup

        unless ( $pkg->{freq} ) {
          print "<TR><TD COLSPAN=2>One-time&nbsp;charge</TD></TR>".
                '<TR><TD>Billed&nbsp;</TD><TD>'.
                pkg_datestr($pkg,'setup',$conf). '</TD></TR>';
        } else {
          print '<TR><TD COLSPAN=2><FONT COLOR="#00CC00"><B>Active</B></FONT>'.
                ',&nbsp;billed&nbsp;'. freq($pkg->{freq}). '</TD></TR>'.
                '<TR><TD>Setup&nbsp;</TD><TD>'.
                pkg_datestr($pkg, 'setup',$conf). '</TD></TR>';
        }

      }

      print "<TR><TD>Last&nbsp;bill&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'last_bill',$conf). '</TD></TR>'
        if $pkg->{'last_bill'};
      print "<TR><TD>Next&nbsp;bill&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'next_bill',$conf). '</TD></TR>'
        if $pkg->{'next_bill'};
      print "<TR><TD>Expires&nbsp;</TD><TD>".
            pkg_datestr($pkg, 'expire',$conf). '</TD></TR>'
        if $pkg->{'expire'};
      if ( $pkg->{freq} ) {
        print '<TR><TD COLSPAN=2>(&nbsp;'. pkg_suspend_link($pkg).
              '&nbsp;|&nbsp;'. pkg_cancel_link($pkg). '&nbsp;)</TD></TR>';
      }

    }

  }

  print "</TABLE></TD>\n";

  if ($rowspan == 0) { print qq!</TR>\n!; next; }

  my $cnt = 0;
  foreach my $svcpart (sort {$a->{svcpart} <=> $b->{svcpart}} @{$pkg->{svcparts}}) {
    foreach my $service (@{$svcpart->{services}}) {
      print '<TR>' if ($cnt > 0);
%>
  <TD><%=svc_link($svcpart,$service)%></TD>
  <TD><%=svc_label_link($svcpart,$service)%><BR>(&nbsp;<%=svc_unprovision_link($service)%>&nbsp;)</TD>
</TR>
<%
      $cnt++;
    }
    if ($svcpart->{count} < $svcpart->{quantity}) {
      print qq!<TR>\n! if ($cnt > 0);
      print qq!  <TD COLSPAN=2>!.svc_provision_link($pkg,$svcpart).qq!</TD>\n</TR>\n!;
    }
  }
}
print '</TABLE>'
}

#end display packages


print <<END;
<SCRIPT>
function cust_pay_areyousure(href) {
    if (confirm("Are you sure you want to delete this payment?")
 == true)
        window.location.href = href;
}
function cust_pay_unapply_areyousure(href) {
    if (confirm("Are you sure you want to unapply this payment?")
 == true)
        window.location.href = href;
}
function cust_credit_areyousure(href) {
    if (confirm("Are you sure you want to delete this credit?")
 == true)
        window.location.href = href;
}
</SCRIPT>
END

if ( $conf->config('payby-default') ne 'HIDE' ) {
  
  #formatting
  print qq!<BR><BR><A NAME="history">Payment History!.
        qq!</A> ( !.
        qq!<A HREF="!. popurl(2). qq!edit/cust_pay.cgi?custnum=$custnum">!.
        qq!Post payment</A> | !.
        qq!<A HREF="!. popurl(2). qq!edit/cust_credit.cgi?$custnum">!.
        qq!Post credit</A> )!;
  
  #get payment history
  #
  # major problem: this whole thing is way too sloppy.
  # minor problem: the description lines need better formatting.
  
  my @history = (); #needed for mod_perl :)
  
  my %target = ();
  
  my @bills = qsearch('cust_bill',{'custnum'=>$custnum});
  foreach my $bill (@bills) {
    my($bref)=$bill->hashref;
    my $bpre = ( $bill->owed > 0 )
                 ? '<b><font size="+1" color="#ff0000"> Open '
                 : '';
    my $bpost = ( $bill->owed > 0 ) ? '</font></b>' : '';
    push @history,
      $bref->{_date} . qq!\t<A HREF="!. popurl(2). qq!view/cust_bill.cgi?! .
      $bref->{invnum} . qq!">${bpre}Invoice #! . $bref->{invnum} .
      qq! (Balance \$! . $bill->owed . qq!)$bpost</A>\t! .
      $bref->{charged} . qq!\t\t\t!;
  
    my(@cust_bill_pay)=qsearch('cust_bill_pay',{'invnum'=> $bref->{invnum} } );
  #  my(@payments)=qsearch('cust_pay',{'invnum'=> $bref->{invnum} } );
  #  my($payment);
    foreach my $cust_bill_pay (@cust_bill_pay) {
      my $payment = $cust_bill_pay->cust_pay;
      my($date,$invnum,$payby,$payinfo,$paid)=($payment->_date,
                                               $cust_bill_pay->invnum,
                                               $payment->payby,
                                               $payment->payinfo,
                                               $cust_bill_pay->amount,
                        );
      $payinfo = 'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4))
        if $payby eq 'CARD';
      my $target = "$payby$payinfo";
      $payby =~ s/^BILL$/Check #/ if $payinfo;
      $payby =~ s/^(CARD|COMP)$/$1 /;
      my $delete = $payment->closed !~ /^Y/i && $conf->exists('deletepayments')
                     ? qq! (<A HREF="javascript:cust_pay_areyousure('${p}misc/delete-cust_pay.cgi?!. $payment->paynum. qq!')">delete</A>)!
                     : '';
      my $unapply =
        $payment->closed !~ /^Y/i && $conf->exists('unapplypayments')
          ? qq! (<A HREF="javascript:cust_pay_unapply_areyousure('${p}misc/unapply-cust_pay.cgi?!. $payment->paynum. qq!')">unapply</A>)!
          : '';
      push @history,
        "$date\tPayment, Invoice #$invnum ($payby$payinfo)$delete$unapply\t\t$paid\t\t\t$target";
    }
  
    my(@cust_credit_bill)=
      qsearch('cust_credit_bill', { 'invnum'=> $bref->{invnum} } );
    foreach my $cust_credit_bill (@cust_credit_bill) {
      my $cust_credit = $cust_credit_bill->cust_credit;
      my($date, $invnum, $crednum, $amount, $reason, $app_date ) = (
        $cust_credit->_date,
        $cust_credit_bill->invnum,
        $cust_credit_bill->crednum,
        $cust_credit_bill->amount,
        $cust_credit->reason,
        time2str("%D", $cust_credit_bill->_date),
      );
      my $delete =
        $cust_credit->closed !~ /^Y/i && $conf->exists('deletecredits')
          ? qq! (<A HREF="javascript:cust_credit_areyousure('${p}misc/delete-cust_credit.cgi?!. $cust_credit->crednum. qq!')">delete</A>)!
          : '';
      push @history,
        "$date\tCredit #$crednum: $reason<BR>".
        "(applied to invoice #$invnum on $app_date)$delete\t\t\t$amount\t";
    }
  }
  
  my @credits = grep { scalar(my @array = $_->cust_credit_refund) }
             qsearch('cust_credit',{'custnum'=>$custnum});
  foreach my $credit (@credits) {
    my($cref)=$credit->hashref;
    my(@cust_credit_refund)=
      qsearch('cust_credit_refund', { 'crednum'=> $cref->{crednum} } );
    foreach my $cust_credit_refund (@cust_credit_refund) {
      my $cust_refund = $cust_credit_refund->cust_credit;
      my($date, $crednum, $amount, $reason, $app_date ) = (
        $credit->_date,
        $credit->crednum,
        $cust_credit_refund->amount,
        $credit->reason,
        time2str("%D", $cust_credit_refund->_date),
      );
      push @history,
        "$date\tCredit #$crednum: $reason<BR>".
        "(applied to refund on $app_date)\t\t\t$amount\t";
    }
  }
  
  @credits = grep { $_->credited  > 0 }
             qsearch('cust_credit',{'custnum'=>$custnum});
  foreach my $credit (@credits) {
    my($cref)=$credit->hashref;
    push @history,
      $cref->{_date} . "\t" .
      qq!<A HREF="! . popurl(2). qq!edit/cust_credit_bill.cgi?!. $cref->{crednum} . qq!">!.
      '<b><font size="+1" color="#ff0000">Unapplied credit #' .
      $cref->{crednum} . "</font></b></A>: ".
      $cref->{reason} . "\t\t\t" . $credit->credited . "\t";
  }
  
  my(@refunds)=qsearch('cust_refund',{'custnum'=> $custnum } );
  foreach my $refund (@refunds) {
    my($rref)=$refund->hashref;
    my($refundnum) = (
      $refund->refundnum,
    );
  
    push @history,
      $rref->{_date} . "\tRefund #$refundnum, (" .
      $rref->{payby} . " " . $rref->{payinfo} . ") by " .
      $rref->{otaker} . " - ". $rref->{reason} . "\t\t\t\t" .
      $rref->{refund};
  }
  
  my @unapplied_payments =
    grep { $_->unapplied > 0 } qsearch('cust_pay', { 'custnum' => $custnum } );
  foreach my $payment (@unapplied_payments) {
    my $payby = $payment->payby;
    my $payinfo = $payment->payinfo;
    #false laziness w/above
    $payinfo = 'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4))
      if $payby eq 'CARD';
    my $target = "$payby$payinfo";
    $payby =~ s/^BILL$/Check #/ if $payinfo;
    $payby =~ s/^(CARD|COMP)$/$1 /;
    my $delete = $payment->closed !~ /^Y/i && $conf->exists('deletepayments')
                   ? qq! (<A HREF="javascript:cust_pay_areyousure('${p}misc/delete-cust_pay.cgi?!. $payment->paynum. qq!')">delete</A>)!
                   : '';
    push @history,
      $payment->_date. "\t".
      '<b><font size="+1" color="#ff0000">Unapplied payment #' .
      $payment->paynum . " ($payby$payinfo)</font></b> ".
      '(<A HREF="'. popurl(2). 'edit/cust_bill_pay.cgi?'. $payment->paynum. '">'.
      "apply</A>)$delete".
      "\t\t" . $payment->unapplied . "\t\t\t$target";
  }
  
          #formatting
          print &table(), <<END;
  <TR>
    <TH>Date</TH>
    <TH>Description</TH>
    <TH><FONT SIZE=-1>Charge</FONT></TH>
    <TH><FONT SIZE=-1>Payment</FONT></TH>
    <TH><FONT SIZE=-1>In-house<BR>Credit</FONT></TH>
    <TH><FONT SIZE=-1>Refund</FONT></TH>
    <TH><FONT SIZE=-1>Balance</FONT></TH>
  </TR>
END
  
  #display payment history
  
  my $balance = 0;
  foreach my $item (sort keyfield_numerically @history) {
    my($date,$desc,$charge,$payment,$credit,$refund,$target)=split(/\t/,$item);
    $charge ||= 0;
    $payment ||= 0;
    $credit ||= 0;
    $refund ||= 0;
    $balance += $charge - $payment;
    $balance -= $credit - $refund;
    $balance = sprintf("%.2f", $balance);
    $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
    $target = '' unless defined $target;
  
    print "<TR><TD><FONT SIZE=-1>";
    print qq!<A NAME="$target">! unless $target && $target{$target}++;
    print time2str("%D",$date);
    print '</A>' if $target && $target{$target} == 1;
    print "</FONT></TD>",
  	"<TD><FONT SIZE=-1>$desc</FONT></TD>",
  	"<TD><FONT SIZE=-1>",
          ( $charge ? "\$".sprintf("%.2f",$charge) : '' ),
          "</FONT></TD>",
  	"<TD><FONT SIZE=-1>",
          ( $payment ? "-&nbsp;\$".sprintf("%.2f",$payment) : '' ),
          "</FONT></TD>",
  	"<TD><FONT SIZE=-1>",
          ( $credit ? "-&nbsp;\$".sprintf("%.2f",$credit) : '' ),
          "</FONT></TD>",
  	"<TD><FONT SIZE=-1>",
          ( $refund ? "\$".sprintf("%.2f",$refund) : '' ),
          "</FONT></TD>",
  	"<TD><FONT SIZE=-1>\$" . $balance,
          "</FONT></TD>",
          "\n";
  }
  
  print "</TABLE>";

}

print '</BODY></HTML>';

#subroutiens
sub keyfield_numerically { (split(/\t/,$a))[0] <=> (split(/\t/,$b))[0]; }

%>

<%


sub get_packages {
  my $cust_main = shift or return undef;
  my $conf = shift;
  
  my @packages = ();
  
  foreach my $cust_pkg (
    $conf->exists('hidecancelledpackages')
      ? $cust_main->ncancelled_pkgs
      : $cust_main->all_pkgs
  ) { 
  
    my $part_pkg = $cust_pkg->part_pkg;
  
    my %pkg = ();
    $pkg{pkgnum} = $cust_pkg->pkgnum;
    $pkg{pkg} = $part_pkg->pkg;
    $pkg{pkgpart} = $part_pkg->pkgpart;
    $pkg{comment} = $part_pkg->getfield('comment');
    $pkg{freq} = $part_pkg->freq;
    $pkg{setup} = $cust_pkg->getfield('setup');
    $pkg{last_bill} = $cust_pkg->getfield('last_bill');
    $pkg{next_bill} = $cust_pkg->getfield('bill');
    $pkg{susp} = $cust_pkg->getfield('susp');
    $pkg{expire} = $cust_pkg->getfield('expire');
    $pkg{cancel} = $cust_pkg->getfield('cancel');
  
    my %svcparts = ();

    foreach my $pkg_svc (
      qsearch('pkg_svc', { 'pkgpart' => $part_pkg->pkgpart })
    ) {
  
      next if ($pkg_svc->quantity == 0);
  
      my $part_svc = qsearchs('part_svc', { 'svcpart' => $pkg_svc->svcpart });
  
      my $svcpart = {};
      $svcpart->{svcpart} = $part_svc->svcpart;
      $svcpart->{svc} = $part_svc->svc;
      $svcpart->{svcdb} = $part_svc->svcdb;
      $svcpart->{quantity} = $pkg_svc->quantity;
      $svcpart->{count} = 0;
  
      $svcpart->{services} = [];

      $svcparts{$svcpart->{svcpart}} = $svcpart;

    }

    foreach my $cust_svc (
      qsearch( 'cust_svc', {
                             'pkgnum' => $cust_pkg->pkgnum,
                             #'svcpart' => $part_svc->svcpart,
                           }
      )
    ) {

      warn "svcnum ". $cust_svc->svcnum. " / svcpart ". $cust_svc->svcpart. "\n";
      my $svc = {
        'svcnum' => $cust_svc->svcnum,
        'label'  => ($cust_svc->label)[1],
      };

      #false laziness with above, to catch extraneous services.  whole
      #damn thing should be OO...
      my $svcpart = ( $svcparts{$cust_svc->svcpart} ||= {
        'svcpart'  => $cust_svc->svcpart,
        'svc'      => $cust_svc->part_svc->svc,
        'svcdb'    => $cust_svc->part_svc->svcdb,
        'quantity' => 0,
        'count'    => 0,
        'services' => [],
      } );

      push @{$svcpart->{services}}, $svc;

      $svcpart->{count}++;

    }

    $pkg{svcparts} = [ values %svcparts ];

    push @packages, \%pkg;
  
  }
  
  return \@packages;

}

sub svc_link {

  my ($svcpart, $svc) = (shift,shift) or return '';
  return qq!<A HREF="${p}view/$svcpart->{svcdb}.cgi?$svc->{svcnum}">$svcpart->{svc}</A>!;

}

sub svc_label_link {

  my ($svcpart, $svc) = (shift,shift) or return '';
  return qq!<A HREF="${p}view/$svcpart->{svcdb}.cgi?$svc->{svcnum}">$svc->{label}</A>!;

}

sub svc_provision_link {
  my ($pkg, $svcpart) = (shift,shift) or return '';
  ( my $svc_nbsp = $svcpart->{svc} ) =~ s/\s+/&nbsp;/g;
  return qq!<A CLASS="provision" HREF="${p}edit/$svcpart->{svcdb}.cgi?! .
         qq!pkgnum$pkg->{pkgnum}-svcpart$svcpart->{svcpart}">! .
         "Provision&nbsp;$svc_nbsp&nbsp;(".
         ($svcpart->{quantity} - $svcpart->{count}).
         ')</A>';
}

sub svc_unprovision_link {
  my $svc = shift or return '';
  return qq!<A HREF="javascript:svc_areyousure('${p}misc/unprovision.cgi?$svc->{svcnum}')">Unprovision</A>!;
}

# This should be generalized to use config options to determine order.
sub pkgsort_pkgnum_cancel {
  if ($a->{cancel} and $b->{cancel}) {
    return ($a->{pkgnum} <=> $b->{pkgnum});
  } elsif ($a->{cancel} or $b->{cancel}) {
    return (-1) if ($b->{cancel});
    return (1) if ($a->{cancel});
    return (0);
  } else {
    return($a->{pkgnum} <=> $b->{pkgnum});
  }
}

sub pkg_datestr {
  my($pkg, $field, $conf) = @_ or return '';
  return '&nbsp;' unless $pkg->{$field};
  my $format = $conf->exists('pkg_showtimes')
               ? '<B>%D</B>&nbsp;<FONT SIZE=-3>%l:%M:%S%P&nbsp;%z</FONT>'
               : '<B>%b&nbsp;%o,&nbsp;%Y</B>';
  ( my $strip = time2str($format, $pkg->{$field}) ) =~ s/ (\d)/$1/g;
  $strip;
}

sub pkg_details_link {
  my $pkg = shift or return '';
  return qq!<a href="${p}view/cust_pkg.cgi?$pkg->{pkgnum}">Details</a>!;
}

sub pkg_change_link {
  my $pkg = shift or return '';
  return qq!<a href="${p}misc/change_pkg.cgi?$pkg->{pkgnum}">Change&nbsp;package</a>!;
}

sub pkg_suspend_link {
  my $pkg = shift or return '';
  return qq!<a href="${p}misc/susp_pkg.cgi?$pkg->{pkgnum}">Suspend</a>!;
}

sub pkg_unsuspend_link {
  my $pkg = shift or return '';
  return qq!<a href="${p}misc/unsusp_pkg.cgi?$pkg->{pkgnum}">Unsuspend</a>!;
}

sub pkg_cancel_link {
  my $pkg = shift or return '';
  return qq!<A HREF="javascript:cust_pkg_areyousure('${p}misc/cancel_pkg.cgi?$pkg->{pkgnum}')">Cancel</A>!;
}

sub pkg_dates_link {
  my $pkg = shift or return '';
  return qq!<A HREF="${p}edit/REAL_cust_pkg.cgi?$pkg->{pkgnum}">Edit&nbsp;dates</A>!;
}

sub pkg_customize_link {
  my $pkg = shift or return '';
  my $custnum = shift;
  return qq!<A HREF="${p}edit/part_pkg.cgi?keywords=$custnum;clone=$pkg->{pkgpart};pkgnum=$pkg->{pkgnum}">Customize</A>!;
}

%>

