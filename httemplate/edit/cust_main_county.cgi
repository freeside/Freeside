<!-- mason kludge -->
%
%
%print header("Edit tax rates", menubar(
%  'Main Menu' => popurl(2),
%));
%
%print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
%      "</FONT>"
%  if $cgi->param('error');
%
%print qq!<FORM ACTION="!, popurl(1),
%    qq!process/cust_main_county.cgi" METHOD=POST>!, &table(), <<END;
%      <TR>
%        <TH><FONT SIZE=-1>Country</FONT></TH>
%        <TH><FONT SIZE=-1>State</FONT></TH>
%        <TH><FONT SIZE=-1>County</FONT></TH>
%        <TH><FONT SIZE=-1>Taxclass</FONT><BR><FONT SIZE=-2>(per-package classification)</FONT></TH>
%END
%
%if ( dbdef->table('cust_main_county')->column('taxname') ) {
%  print '<TH><FONT SIZE=-1>Tax name</FONT><BR><FONT SIZE=-2>(printed on invoices)</FONT></TH>';
%}
%
%print <<END;
%        <TH><FONT SIZE=-1>Tax</FONT></TH>
%        <TH><FONT SIZE=-1>Exempt<BR>per<BR>month</TH>
%END
%
%if ( dbdef->table('cust_main_county')->column('setuptax') ) {
%  print '<TH><FONT SIZE=-1>Setup<BR>fee<BR>exempt</TH>';
%}
%if ( dbdef->table('cust_main_county')->column('recurtax') ) {
%  print '<TH><FONT SIZE=-1>Recurring<BR>fee<BR>exempt</TH>';
%}
%
%print '</TR>';
%
%foreach my $cust_main_county ( sort {    $a->country cmp $b->country
%                                      or $a->state   cmp $b->state
%                                      or $a->county  cmp $b->county
%                                    } qsearch('cust_main_county',{}) ) {
%  my($hashref)=$cust_main_county->hashref;
%  print <<END;
%      <TR>
%        <TD BGCOLOR="#ffffff">$hashref->{country}</TD>
%END
%
%  print "<TD", $hashref->{state}
%      ? ' BGCOLOR="#ffffff">'.$hashref->{state}
%      : ' BGCOLOR="#cccccc">(ALL)'
%    , "</TD>";
%
%  print "<TD", $hashref->{county}
%      ? ' BGCOLOR="#ffffff">'. $hashref->{county}
%      : ' BGCOLOR="#cccccc">(ALL)'
%    , "</TD>";
%
%  print "<TD", $hashref->{taxclass}
%      ? ' BGCOLOR="#ffffff">'. $hashref->{taxclass}
%      : ' BGCOLOR="#cccccc">(ALL)'
%    , "</TD>";
%
%  print qq!<TD><INPUT TYPE="text" NAME="taxname!, $hashref->{taxnum},
%        qq!" VALUE="!, $hashref->{taxname}, qq!"></TD>!
%    if dbdef->table('cust_main_county')->column('taxname');
%
%  print qq!<TD><TABLE><TR><TD><INPUT TYPE="text" NAME="tax!, $hashref->{taxnum},
%        qq!" VALUE="!, $hashref->{tax}, qq!" SIZE=6 MAXLENGTH=6></TD><TD>%</TD></TR></TABLE></TD>!;
%  print qq!<TD><TABLE><TR><TD>\$</TD><TD><INPUT TYPE="text" NAME="exempt_amount!, $hashref->{taxnum},
%        qq!" VALUE="!, $hashref->{exempt_amount}||0, qq!" SIZE=6></TD></TR></TABLE></TD>!;
%
%  print qq!<TD><INPUT TYPE="checkbox" NAME="setuptax!. $hashref->{taxnum}.
%        '" VALUE="Y"'.
%        ( $hashref->{setuptax} =~ /^Y$/i ? ' CHECKED' : '' ).
%        '></TD>'
%    if dbdef->table('cust_main_county')->column('setuptax');
%
%  print qq!<TD><INPUT TYPE="checkbox" NAME="recurtax!. $hashref->{taxnum}.
%        '" VALUE="Y"'.
%        ( $hashref->{recurtax} =~ /^Y$/i ? ' CHECKED' : '' ).
%        '></TD>'
%    if dbdef->table('cust_main_county')->column('recurtax');
%
%  print '</TR>';
%
%}
%
%print <<END;
%    </TABLE>
%    <INPUT TYPE="submit" VALUE="Apply changes">
%    </FORM>
%    </CENTER>
%  </BODY>
%</HTML>
%END
%
%

