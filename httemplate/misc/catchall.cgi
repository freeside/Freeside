<% include('/elements/header.html', 'Domain Catchall Edit') %>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/catchall.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum |h %>">
Service #<FONT SIZE=+1><B><% $svcnum ? $svcnum : ' (NEW)' |h %></B></FONT>
<BR><BR>

<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum |h %>">

<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

% my $domain   = $svc_domain->domain;
% my $catchall = $svc_domain->catchall;

<INPUT TYPE="hidden" NAME="domain" VALUE="<% $domain |h %>">

Mail to <I>(anything)</I>@<B><% $domain |h %></B> forwards to <SELECT NAME="catchall" SIZE=1>
% foreach $_ (keys %email) {
    <OPTION<% $_ eq $catchall ? ' SELECTED' : '' %> VALUE="<% $_ %>"><% $email{$_} %>
% }
</SELECT>
<BR><BR>

<INPUT TYPE="submit" VALUE="Submit">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit domain catchall');

my $conf = new FS::Conf;

my($svc_domain, $svcnum, $pkgnum, $svcpart, $part_svc);
if ( $cgi->param('error') ) {
  $svc_domain = new FS::svc_domain ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_domain')
  } );
  $svcnum = $svc_domain->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
      or die "Unknown (svc_domain) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { 

    die "Invalid (svc_domain) svcnum!";

  }
}

my %email;
if ($pkgnum) {

  #find all possible user svcnums (and emails)

  #starting with that currently attached
  if ($svc_domain->catchall) {
    my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$svc_domain->catchall});
    $email{$svc_domain->catchall} = $svc_acct->email;
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
      my($i_cust_svc);
      foreach $i_cust_svc ( qsearch('cust_svc',{'pkgnum'=>$cust_pkgnum,'svcpart'=>$acct_svcpart}) ) {
        my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$i_cust_svc->getfield('svcnum')});
        $email{$svc_acct->getfield('svcnum')}=$svc_acct->email;
      }  
    }
  }

} else {

  my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$svc_domain->catchall});
  $email{$svc_domain->catchall} = $svc_acct->email;
}

# add an absence of a catchall
$email{''} = "(none)";

my $p1 = popurl(1);

</%init>
