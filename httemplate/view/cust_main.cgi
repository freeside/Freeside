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

%>

<STYLE TYPE="text/css">
.package TH { font-size: medium }
.package TR { font-size: smaller }
.package .provision { font-weight: bold }
</STYLE>

<%

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my $custnum = $1;
my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Customer not found!" unless $cust_main;

print qq!<A HREF="${p}edit/cust_main.cgi?$custnum">Edit this customer</A>!;

%>

<SCRIPT>
function cancel_areyousure(href) {
    if (confirm("Perminantly delete all services and cancel this customer?") == true)
        window.location.href = href;
}
</SCRIPT>

<%

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

%>

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

<%

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
  <TH>Package</TH>
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
  <TD ROWSPAN=<%=$rowspan%>>
    <%=$pkg->{pkgnum}%>:
    <%=$pkg->{pkg}%> - <%=$pkg->{comment}%><BR>
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
      print qq!  <TD COLSPAN=2>!.svc_provision_link($pkg, $svcpart, $conf).qq!</TD>\n</TR>\n!;
    }
  }
}
print '</TABLE>';
}

#end display packages
%>

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
function cust_credit_unapply_areyousure(href) {
    if (confirm("Are you sure you want to unapply this credit?")
 == true)
        window.location.href = href;
}
function cust_credit_areyousure(href) {
    if (confirm("Are you sure you want to delete this credit?")
 == true)
        window.location.href = href;
}
</SCRIPT>

<% if ( $conf->config('payby-default') ne 'HIDE' ) { %>
  
  <BR><BR><A NAME="history">Payment History</A>
  (<A HREF="<%= $p %>edit/cust_pay.cgi?custnum=<%= $custnum %>">Post payment</A>
  | <A HREF="<%= $p %>edit/cust_credit.cgi?<%= $custnum %>">Post credit</A>)

  <%
  #get payment history
  my @history = ();

  #invoices
  foreach my $cust_bill ($cust_main->cust_bill) {
    my $pre = ( $cust_bill->owed > 0 )
                ? '<B><FONT SIZE="+1" COLOR="#FF0000">Open '
                : '';
    my $post = ( $cust_bill->owed > 0 ) ? '</FONT></B>' : '';
    my $invnum = $cust_bill->invnum;
    push @history, {
      'date'   => $cust_bill->_date,
      'desc'   => qq!<A HREF="${p}view/cust_bill.cgi?$invnum">!. $pre.
                  "Invoice #$invnum (Balance \$". $cust_bill->owed. ')'.
                  $post. '</A>',
      'charge' => $cust_bill->charged,
    };
  }

  #payments (some false laziness w/credits)
  foreach my $cust_pay ($cust_main->cust_pay) {

    my $payby = $cust_pay->payby;
    my $payinfo = $cust_pay->payinfo;
    my @cust_bill_pay = $cust_pay->cust_bill_pay;

    $payinfo = 'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4))
      if $payby eq 'CARD';
    my $target = "$payby$payinfo";
    $payby =~ s/^BILL$/Check #/ if $payinfo;
    $payby =~ s/^BILL$//;
    $payby =~ s/^(CARD|COMP)$/$1 /;
    my $info = $payby ? " ($payby$payinfo)" : '';

    my( $pre, $post, $desc, $apply, $ext ) = ( '', '', '', '', '' );
    if ( scalar(@cust_bill_pay) == 0 ) {
      #completely unapplied
      $pre = '<B><FONT COLOR="#FF0000">Unapplied ';
      $post = '</FONT></B>';
      $apply = qq! (<A HREF="${p}edit/cust_bill_pay.cgi?!.
               $cust_pay->paynum. '">apply</A>)';
    } elsif ( scalar(@cust_bill_pay) == 1 && $cust_pay->unapplied == 0 ) {
      #applied to one invoice
      $desc = ' applied to Invoice #'. $cust_bill_pay[0]->invnum;
    } else {
      #complicated
      $desc = '<BR>';
      foreach my $cust_bill_pay (@cust_bill_pay) {
        $desc .= '&nbsp;&nbsp;'.
                 '$'. $cust_bill_pay->amount.
                 ' applied to Invoice #'. $cust_bill_pay->invnum.
                 '<BR>';
                 #' on '. time2str("%D", $cust_bill_pay->_date).

      }
      if ( $cust_pay->unapplied > 0 ) {
        $desc .= '&nbsp;&nbsp;'.
                 '<B><FONT COLOR="#FF0000">$'.
                 $cust_pay->unapplied. ' unapplied</FONT></B>'.
                 qq! (<A HREF="${p}edit/cust_bill_pay.cgi?!.
                 $cust_pay->paynum. '">apply</A>)'.
                 '<BR>';
      }
    }

    my $delete = '';
    if ( $cust_pay->closed !~ /^Y/i && $conf->exists('deletepayments') ) {
      $delete = qq! (<A HREF="javascript:cust_pay_areyousure('!.
                qq!${p}misc/delete-cust_pay.cgi?!. $cust_pay->paynum.
                qq!')">delete</A>)!;
    }

    my $unapply = '';
    if (    $cust_pay->closed !~ /^Y/i
         && $conf->exists('unapplypayments')
         && scalar(@cust_bill_pay)           ) {
      $unapply = qq! (<A HREF="javascript:cust_pay_unapply_areyousure('!.
                 qq!${p}misc/unapply-cust_pay.cgi?!. $cust_pay->paynum.
                 qq!')">unapply</A>)!;
    }

    push @history, {
      'date'    => $cust_pay->_date,
      'desc'    => $pre. "Payment$post$info$desc".
                   "$apply$delete$unapply",
      'payment' => $cust_pay->paid,
      'target'  => $target,
    };
  }

  #credits (some false laziness w/payments)
  foreach my $cust_credit ($cust_main->cust_credit) {

    my @cust_credit_bill = $cust_credit->cust_credit_bill;
    my @cust_credit_refund = $cust_credit->cust_credit_refund;

    my( $pre, $post, $desc, $apply, $ext ) = ( '', '', '', '', '' );
    if (    scalar(@cust_credit_bill)   == 0
         && scalar(@cust_credit_refund) == 0 ) {
      #completely unapplied
      $pre = '<B><FONT COLOR="#FF0000">Unapplied ';
      $post = '</FONT></B>';
      $apply = qq! (<A HREF="${p}edit/cust_credit_bill.cgi?!.
               $cust_credit->crednum. '">apply</A>)';
    } elsif (    scalar(@cust_credit_bill)   == 1
              && scalar(@cust_credit_refund) == 0
              && $cust_credit->credited == 0      ) {
      #applied to one invoice
      $desc = ' applied to Invoice #'. $cust_credit_bill[0]->invnum;
    } elsif (    scalar(@cust_credit_bill)   == 0
              && scalar(@cust_credit_refund) == 1
              && $cust_credit->credited == 0      ) {
      #applied to one refund
      $desc = ' refunded on '.  time2str("%D", $cust_credit_refund[0]->_date);
    } else {
      #complicated
      $desc = '<BR>';
      foreach my $app ( sort { $a->_date <=> $b->_date }
                             ( @cust_credit_bill, @cust_credit_refund ) ) {
        if ( $app->isa('FS::cust_credit_bill') ) {
          $desc .= '&nbsp;&nbsp;'.
                   '$'. $app->amount.
                   ' applied to Invoice #'. $app->invnum.
                   '<BR>';
                   #' on '. time2str("%D", $app->_date).
        } elsif ( $app->isa('FS::cust_credit_refund') ) {
          $desc .= '&nbsp;&nbsp;'.
                   '$'. $app->amount.
                   ' refunded on'. time2str("%D", $app->_date).
                   '<BR>';
        } else {
          die "$app is not a FS::cust_credit_bill or a FS::cust_credit_refund";
        }
      }
      if ( $cust_credit->credited > 0 ) {
        $desc .= ' - <B><FONT COLOR="#FF0000">$'.
                 $cust_credit->unapplied. ' unapplied</FONT></B>'.
                 qq! (<A HREF="${p}edit/cust_credit_bill.cgi?!.
                 $cust_credit->crednum. '">apply</A>'.
                 '<BR>';
      }
    }
#
    my $delete = '';
    if ( $cust_credit->closed !~ /^Y/i && $conf->exists('deletecredits') ) {
      $delete = qq! (<A HREF="javascript:cust_credit_areyousure('!.
                qq!${p}misc/delete-cust_credit.cgi?!. $cust_credit->crednum.
                qq!')">delete</A>)!;
    }
    
    my $unapply = '';
    if (    $cust_credit->closed !~ /^Y/i
         && $conf->exists('unapplycredits')
         && scalar(@cust_credit_bill)       ) {
      $unapply = qq! (<A HREF="javascript:cust_credit_unapply_areyousure('!.
                 qq!${p}misc/unapply-cust_credit.cgi?!. $cust_credit->crednum.
                 qq!')">unapply</A>)!;
    }
    
    push @history, {
      'date'   => $cust_credit->_date,
      'desc'   => $pre. "Credit$post by ". $cust_credit->otaker.
                  ' ('. $cust_credit->reason. ')'.
                  "$desc$apply$delete$unapply",
      'credit' => $cust_credit->amount,
    };

  }

  #refunds
  foreach my $cust_refund ($cust_main->cust_refund) {

    my $payby = $cust_refund->payby;
    my $payinfo = $cust_refund->payinfo;

    $payinfo = 'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4))
      if $payby eq 'CARD';
    $payby =~ s/^BILL$/Check #/ if $payinfo;
    $payby =~ s/^(CARD|COMP)$/$1 /;

    push @history, {
      'date'   => $cust_refund->_date,
      'desc'   => "Refund ($payby$payinfo) by ". $cust_refund->otaker,
      'refund' => $cust_refund->refund,
    };
  
  }
  
  %>
  
  <%= table() %>
  <TR>
    <TH>Date</TH>
    <TH>Description</TH>
    <TH><FONT SIZE=-1>Charge</FONT></TH>
    <TH><FONT SIZE=-1>Payment</FONT></TH>
    <TH><FONT SIZE=-1>In-house<BR>Credit</FONT></TH>
    <TH><FONT SIZE=-1>Refund</FONT></TH>
    <TH><FONT SIZE=-1>Balance</FONT></TH>
  </TR>

  <%
  #display payment history

  my %target;
  my $balance = 0;
  foreach my $item ( sort { $a->{'date'} <=> $b->{'date'} } @history ) {

    my $charge  = exists($item->{'charge'})
                    ? sprintf('$%.2f', $item->{'charge'})
                    : '';
    my $payment = exists($item->{'payment'})
                    ? sprintf('-&nbsp;$%.2f', $item->{'payment'})
                    : '';
    my $credit  = exists($item->{'credit'})
                    ? sprintf('-&nbsp;$%.2f', $item->{'credit'})
                    : '';
    my $refund  = exists($item->{'refund'})
                    ? sprintf('$%.2f', $item->{'refund'})
                    : '';

    my $target = exists($item->{'target'}) ? $item->{'target'} : '';

    $balance += $item->{'charge'}  if exists $item->{'charge'};
    $balance -= $item->{'payment'} if exists $item->{'payment'};
    $balance -= $item->{'credit'}  if exists $item->{'credit'};
    $balance += $item->{'refund'}  if exists $item->{'refund'};
    $balance = sprintf("%.2f", $balance);
    $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp

  %>
  
    <TR>
      <TD>
        <% unless ( !$target || $target{$target}++ ) { %>
          <A NAME="<%= $target %>">
        <% } %>
        <%= time2str("%D",$item->{'date'}) %>
        <% if ( $target && $target{$target} == 1 ) { %>
          </A>
        <% } %>
        </FONT>
      </TD>
      <TD><%= $item->{'desc'} %></TD>
      <TD><%= $charge  %></TD>
      <TD><%= $payment %></TD>
      <TD><%= $credit  %></TD>
      <TD><%= $refund  %></TD>
      <TD>$<%= $balance %></TD>
    </TR>

  <% } %>
  
  </TABLE>

<% } %>

</BODY></HTML>

<%
#subroutines

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
  my ($pkg, $svcpart, $conf) = @_;
  ( my $svc_nbsp = $svcpart->{svc} ) =~ s/\s+/&nbsp;/g;
  my $pkgnum_svcpart = "pkgnum$pkg->{pkgnum}-svcpart$svcpart->{svcpart}";
  my $num_left = $svcpart->{quantity} - $svcpart->{count};

  my $link = qq!<A CLASS="provision" HREF="${p}edit/$svcpart->{svcdb}.cgi?!.
             qq!$pkgnum_svcpart">!.
             "Provision&nbsp;$svc_nbsp&nbsp;($num_left)</A>";
  if ( $conf->exists('legacy_link') ) {
    $link .= '<BR>'.
             qq!<A CLASS="provision" HREF="${p}misc/link.cgi?!.
             qq!$pkgnum_svcpart">!.
            "Link&nbsp;to&nbsp;legacy&nbsp;$svc_nbsp&nbsp;($num_left)</A>";
  }
  $link;
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

#sub pkg_details_link {
#  my $pkg = shift or return '';
#  return qq!<a href="${p}view/cust_pkg.cgi?$pkg->{pkgnum}">Details</a>!;
#}

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
  qq!<A HREF="javascript:cust_pkg_areyousure('${p}misc/cancel_pkg.cgi?$pkg->{pkgnum}')">Cancel now</A> | !.
  qq!<A HREF="${p}misc/expire_pkg.cgi?$pkg->{pkgnum}">Cancel later</A>!;
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

