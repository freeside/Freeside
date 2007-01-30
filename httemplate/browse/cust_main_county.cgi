<% include('/elements/header.html', "Tax Rate Listing", menubar(
  'Edit tax rates' => $p. "edit/cust_main_county.cgi",
)) %>

    Click on <u>expand country</u> to specify a country's tax rates by state.
    <BR>Click on <u>expand state</u> to specify a state's tax rates by county.
%
%my $conf = new FS::Conf;
%my $enable_taxclasses = $conf->exists('enable_taxclasses');
%
%if ( $enable_taxclasses ) { 


  <BR>Click on <u>expand taxclasses</u> to specify tax classes
% } 


<BR><BR>
<% table() %>

  <TR>
    <TH><FONT SIZE=-1>Country</FONT></TH>
    <TH><FONT SIZE=-1>State</FONT></TH>
    <TH>County</TH>
    <TH>Taxclass<BR><FONT SIZE=-1>(per-package classification)</FONT></TH>
    <TH>Tax name<BR><FONT SIZE=-1>(printed on invoices)</FONT></TH>
    <TH><FONT SIZE=-1>Tax</FONT></TH>
    <TH><FONT SIZE=-1>Exemption</TH>
  </TR>
%
%my @regions = sort {    $a->country  cmp $b->country
%                     or $a->state    cmp $b->state
%                     or $a->county   cmp $b->county
%                     or $a->taxclass cmp $b->taxclass
%                   } qsearch('cust_main_county',{});
%
%my $sup=0;
%#foreach $cust_main_county ( @regions ) {
%for ( my $i=0; $i<@regions; $i++ ) { 
%  my $cust_main_county = $regions[$i];
%  my $hashref = $cust_main_county->hashref;
%
%  

      <TR>
        <TD BGCOLOR="#ffffff"><% $hashref->{country} %></TD>
%
%
%  my $j;
%  if ( $sup ) {
%    $sup--;
%  } else {
%
%    #lookahead
%    for ( $j=1; $i+$j<@regions; $j++ ) {
%      last if $hashref->{country} ne $regions[$i+$j]->country
%           || $hashref->{state} ne $regions[$i+$j]->state
%           || $hashref->{tax} != $regions[$i+$j]->tax
%           || $hashref->{exempt_amount} != $regions[$i+$j]->exempt_amount
%           || $hashref->{setuptax} ne $regions[$i+$j]->setuptax
%           || $hashref->{recurtax} ne $regions[$i+$j]->recurtax;
%    }
%
%    my $newsup=0;
%    if ( $j>1 && $i+$j+1 < @regions
%         && ( $hashref->{state} ne $regions[$i+$j+1]->state 
%              || $hashref->{country} ne $regions[$i+$j+1]->country
%              )
%         && ( ! $i
%              || $hashref->{state} ne $regions[$i-1]->state 
%              || $hashref->{country} ne $regions[$i-1]->country
%              )
%       ) {
%       $sup = $j-1;
%    } else {
%      $j = 1;
%    }
%
%    


    <TD ROWSPAN=<% $j %><%
      $hashref->{state}
        ? ' BGCOLOR="#ffffff">'. $hashref->{state}
        : qq! BGCOLOR="#cccccc">(ALL) <FONT SIZE=-1>!.
          qq!<A HREF="${p}edit/cust_main_county-expand.cgi?!. $hashref->{taxnum}.
          qq!">expand country</A></FONT>!
      %>
% if ( $j>1 ) { 

        <FONT SIZE=-1><A HREF="<% $p %>edit/process/cust_main_county-collapse.cgi?<% $hashref->{taxnum} %>">collapse state</A></FONT>
% } 


    </TD>
% } 
% #  $sup=$newsup; 


    <TD
% if ( $hashref->{county} ) {
%            
 BGCOLOR="#ffffff"><% $hashref->{county} %>
% } else {
%            
 BGCOLOR="#cccccc">(ALL)
% if ( $hashref->{state} ) { 

                 <FONT SIZE=-1><A HREF="<% $p %>edit/cust_main_county-expand.cgi?<% $hashref->{taxnum} %>">expand state</A></FONT>
% } 
% } 

    </TD>

    <TD
% if ( $hashref->{taxclass} ) {
%            
 BGCOLOR="#ffffff"><% $hashref->{taxclass} %>
% } else {
%            
 BGCOLOR="#cccccc">(ALL)
% if ( $enable_taxclasses ) { 

                 <FONT SIZE=-1><A HREF="<% $p %>edit/cust_main_county-expand.cgi?taxclass<% $hashref->{taxnum} %>">expand taxclasses</A></FONT>
% } 
% } 

    </TD>

    <TD
% if ( $hashref->{taxname} ) {
%            
 BGCOLOR="#ffffff"><% $hashref->{taxname} %>
% } else {
%            
 BGCOLOR="#cccccc">Tax
% } 

    </TD>

    <TD BGCOLOR="#ffffff"><% $hashref->{tax} %>%</TD>

    <TD BGCOLOR="#ffffff">
% if ( $hashref->{exempt_amount} > 0 ) { 

        $<% sprintf("%.2f", $hashref->{exempt_amount} ) %>&nbsp;per&nbsp;month<BR>
% } 
% if ( $hashref->{setuptax} =~ /^Y$/i ) { 

        Setup&nbsp;fee<BR>
% } 
% if ( $hashref->{recurtax} =~ /^Y$/i ) { 

        Recurring&nbsp;fee<BR>
% } 


    </TD>

  </TR>
% } 


</TABLE>

<% include('/elements/footer.html') %>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
</%init>
