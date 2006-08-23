<!-- mason kludge -->
%
%
%my $svc_acct_pop;
%if ( $cgi->param('error') ) {
%  $svc_acct_pop = new FS::svc_acct_pop ( {
%    map { $_, scalar($cgi->param($_)) } fields('svc_acct_pop')
%  } );
%} elsif ( $cgi->keywords ) { #editing
%  my($query)=$cgi->keywords;
%  $query =~ /^(\d+)$/;
%  $svc_acct_pop=qsearchs('svc_acct_pop',{'popnum'=>$1});
%} else { #adding
%  $svc_acct_pop = new FS::svc_acct_pop {};
%}
%my $action = $svc_acct_pop->popnum ? 'Edit' : 'Add';
%my $hashref = $svc_acct_pop->hashref;
%
%my $p1 = popurl(1);
%print header("$action Access Number", menubar(
%  'Main Menu' => popurl(2),
%  'View all Access Numbers' => popurl(2). "browse/svc_acct_pop.cgi",
%));
%
%print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
%      "</FONT>"
%  if $cgi->param('error');
%
%print qq!<FORM ACTION="${p1}process/svc_acct_pop.cgi" METHOD=POST>!;
%
%#display
%
%print qq!<INPUT TYPE="hidden" NAME="popnum" VALUE="$hashref->{popnum}">!,
%      "POP #", $hashref->{popnum} ? $hashref->{popnum} : "(NEW)";
%
%print <<END;
%<PRE>
%City      <INPUT TYPE="text" NAME="city" SIZE=32 VALUE="$hashref->{city}">
%State     <INPUT TYPE="text" NAME="state" SIZE=16 MAXLENGTH=16 VALUE="$hashref->{state}">
%Area Code <INPUT TYPE="text" NAME="ac" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{ac}">
%Exchange  <INPUT TYPE="text" NAME="exch" SIZE=4 MAXLENGTH=3 VALUE="$hashref->{exch}">
%Local     <INPUT TYPE="text" NAME="loc" SIZE=5 MAXLENGTH=4 VALUE="$hashref->{loc}">
%</PRE>
%END
%
%print qq!<BR><INPUT TYPE="submit" VALUE="!,
%      $hashref->{popnum} ? "Apply changes" : "Add Access Number",
%      qq!">!;
%
%print <<END;
%    </FORM>
%  </BODY>
%</HTML>
%END
%
%

