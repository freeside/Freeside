<!-- mason kludge -->
<%

my $conf = new FS::Conf;
my $mydomain = $conf->config('domain');

my($svcnum, $pkgnum, $svcpart, $part_svc, $svc_forward);
if ( $cgi->param('error') ) {
  $svc_forward = new FS::svc_forward ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_forward')
  } );
  $svcnum = $svc_forward->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {

  my($query) = $cgi->keywords;

  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_forward=qsearchs('svc_forward',{'svcnum'=>$svcnum})
      or die "Unknown (svc_forward) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_forward = new FS::svc_forward({});

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svcnum='';

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_forward->setfield( $part_svc_column->columnname,
                              $part_svc_column->columnvalue,
                            );
    }
  }

}
my $action = $svc_forward->svcnum ? 'Edit' : 'Add';

my %email;
if ($pkgnum) {

  #find all possible user svcnums (and emails)

  #starting with those currently attached
  if ( $svc_forward->srcsvc ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_forward->srcsvc } );
    $email{$svc_forward->srcsvc} = $svc_acct->email;
  }
  if ( $svc_forward->dstsvc ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_forward->dstsvc } );
    $email{$svc_forward->dstsvc} = $svc_acct->email;
  }

  #and including the rest for this customer
  my($u_part_svc,@u_acct_svcparts);
  foreach $u_part_svc ( qsearch('part_svc',{'svcdb'=>'svc_acct'}) ) {
    push @u_acct_svcparts,$u_part_svc->getfield('svcpart');
  }

  my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  my($custnum)=$cust_pkg->getfield('custnum');
  my($i_cust_pkg);
  foreach $i_cust_pkg ( qsearch('cust_pkg',{'custnum'=>$custnum}) ) {
    my($cust_pkgnum)=$i_cust_pkg->getfield('pkgnum');
    my($acct_svcpart);
    foreach $acct_svcpart (@u_acct_svcparts) {   #now find the corresponding 
                                              #record(s) in cust_svc ( for this
                                              #pkgnum ! )
      foreach my $i_cust_svc (
        qsearch( 'cust_svc', { 'pkgnum'  => $cust_pkgnum,
                               'svcpart' => $acct_svcpart } )
      ) {
        my $svc_acct =
          qsearchs( 'svc_acct', { 'svcnum' => $i_cust_svc->svcnum } );
        $email{$svc_acct->svcnum} = $svc_acct->email;
      }  
    }
  }

} elsif ( $action eq 'Edit' ) {

  my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$svc_forward->srcsvc});
  $email{$svc_forward->srcsvc} = $svc_acct->email;

  $svc_acct=qsearchs('svc_acct',{'svcnum'=>$svc_forward->dstsvc});
  $email{$svc_forward->dstsvc} = $svc_acct->email;

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

my($srcsvc,$dstsvc,$dst)=(
  $svc_forward->srcsvc,
  $svc_forward->dstsvc,
  $svc_forward->dst,
);

#display

%>

<%= header("Mail Forward $action") %>

<% if ( $cgi->param('error') ) { %>
  <FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
  <BR><BR>
<% } %>

Service #<%= $svcnum ? "<B>$svcnum</B>" : " (NEW)" %><BR>
Service: <B><%= $part_svc->svc %></B><BR><BR>

<FORM NAME="dummy">

<%= ntable("#cccccc",2) %>
<TR><TD ALIGN="right">Email to</TD><TD><SELECT NAME="srcsvc" SIZE=1>
<% foreach $_ (keys %email) { %>
  <OPTION<%= $_ eq $srcsvc ? " SELECTED" : "" %> VALUE="<%= $_ %>"><%= $email{$_} %></OPTION>
<% } %>
</SELECT></TD></TR>

<%
  tie my %tied_email, 'Tie::IxHash',
    ''  => 'SELECT DESTINATION',
    %email,
    '0' => '(other email address)';
  my $widget = new HTML::Widgets::SelectLayers(
    'selected_layer' => $dstsvc,
    'options'        => \%tied_email,
    'form_name'      => 'dummy',
    'form_action'    => 'process/svc_forward.cgi',
    'form_select'    => ['srcsvc'],
    'html_between'   => '</TD></TR></TABLE>',
    'layer_callback' => sub {
      my $layer = shift;
      my $html = qq!<INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">!.
                 qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!.
                 qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">!.
                 qq!<INPUT TYPE="hidden" NAME="dstsvc" VALUE="$layer">!;
      if ( $layer eq '0' ) {
        $html .= ntable("#cccccc",2).
                 '<TR><TD ALIGN="right">Destination email</TD>'.
                 qq!<TD><INPUT TYPE="text" NAME="dst" VALUE="$dst"></TD>!.
                 '</TR></TABLE>';
      }
      $html .= '<BR><INPUT TYPE="submit" VALUE="Submit">';
      $html;
    },
  );
%>

<TR><TD ALIGN="right">Forwards to</TD>
<TD><%= $widget->html %>
  </BODY>
</HTML>
