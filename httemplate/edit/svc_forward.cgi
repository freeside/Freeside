<% include('/elements/header.html', "Mail Forward $action") %>

<% include('/elements/error.html') %>

Service #<% $svcnum ? "<B>$svcnum</B>" : " (NEW)" %><BR>
Service: <B><% $part_svc->svc %></B><BR><BR>

<FORM ACTION="process/svc_forward.cgi" METHOD="POST">
<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

<SCRIPT TYPE="text/javascript">
function srcchanged(what) {
  if ( what.options[what.selectedIndex].value == 0 ) {
    what.form.src.disabled = false;
    what.form.src.style.backgroundColor = "white";
  } else {
    what.form.src.disabled = true;
    what.form.src.style.backgroundColor = "lightgrey";
  }
}
function dstchanged(what) {
  if ( what.options[what.selectedIndex].value == 0 ) {
    what.form.dst.disabled = false;
    what.form.dst.style.backgroundColor = "white";
  } else {
    what.form.dst.disabled = true;
    what.form.dst.style.backgroundColor = "lightgrey";
  }
}
</SCRIPT>

<% ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right">Email to</TD>
  <TD>
%   if ( $conf->exists('svc_forward-no_srcsvc') ) {
      <INPUT NAME="srcsrc" TYPE="hidden" VALUE="0">
%   } else {
      <SELECT NAME="srcsvc" SIZE=1 onChange="srcchanged(this)">
%       foreach $_ (keys %email) { 
          <OPTION VALUE="<% $_ %>"
                  <% $_ eq $srcsvc ? 'SELECTED' : '' %>
          ><% $email{$_} %></OPTION>
%       } 
        <OPTION VALUE="0" <% $src ? 'SELECTED' : '' %>
        >(other email address)</OPTION>
      </SELECT>
%   }

%   my $src_disabled =    $src
%                      || $conf->exists('svc_forward-no_srcsvc')
%                      || !scalar(%email);
    <INPUT NAME  = "src"
           TYPE  = "text"
           VALUE = "<% $src %>"
           <% $src_disabled ? '' : 'DISABLED STYLE="background-color: lightgrey"' %>
    >

  </TD>
</TR>

<TR><TD ALIGN="right">Forwards to</TD>
<TD><SELECT NAME="dstsvc" SIZE=1 onChange="dstchanged(this)">
% foreach $_ (keys %email) { 

  <OPTION<% $_ eq $dstsvc ? " SELECTED" : "" %> VALUE="<% $_ %>"><% $email{$_} %></OPTION>
% } 

<OPTION <% $dst ? 'SELECTED' : '' %> VALUE="0">(other email address)</OPTION>
</SELECT>
<INPUT TYPE="text" NAME="dst" VALUE="<% $dst %>" <% ( $dst || !scalar(%email) ) ? '' : 'DISABLED STYLE="background-color: lightgrey"' %>>
</TD></TR>
    </TABLE>
<BR><INPUT TYPE="submit" VALUE="Submit">
</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;

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

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_forward = new FS::svc_forward({});

  $svcnum='';

  $svc_forward->set_default_and_fixed;

} else { #editing

  my($query) = $cgi->keywords;

  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_forward=qsearchs('svc_forward',{'svcnum'=>$svcnum})
    or die "Unknown (svc_forward) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;
  
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svc_forward->svcnum ? 'Edit' : 'Add';

my %email;

#starting with those currently attached
foreach my $method (qw( srcsvc_acct dstsvc_acct )) {
  my $svc_acct = $svc_forward->$method();
  $email{$svc_acct->svcnum} = $svc_acct->email if $svc_acct;
}

if ($pkgnum) {

  #find all possible user svcnums (and emails)

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

} elsif ( $action eq 'Add' ) {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

my($srcsvc,$dstsvc,$dst)=(
  $svc_forward->srcsvc,
  $svc_forward->dstsvc,
  $svc_forward->dst,
);
my $src = $svc_forward->dbdef_table->column('src') ? $svc_forward->src : '';

</%init>
