% die "access denied"
% unless $FS::CurrentUser::CurrentUser->access_right('View customer services')
%     || $FS::CurrentUser::CurrentUser->access_right('View customer'); #XXX remove me
%
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/;
%my $svcnum = $1;
%my $svc_www = qsearchs({
%  'select'    => 'svc_www.*',
%  'table'     => 'svc_www',
%  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
%                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
%                 ' LEFT JOIN cust_main USING ( custnum ) ',
%  'hashref'   => { 'svcnum' => $svcnum },
%  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%}) or die "svc_www: Unknown svcnum $svcnum";
%
%#false laziness w/all svc_*.cgi
%my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
%my $pkgnum = $cust_svc->getfield('pkgnum');
%my($cust_pkg, $custnum);
%if ($pkgnum) {
%  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
%  $custnum = $cust_pkg->custnum;
%} else {
%  $cust_pkg = '';
%  $custnum = '';
%}
%#eofalse
%
%my $part_svc=qsearchs('part_svc',{'svcpart'=>$cust_svc->svcpart})
%  or die "svc_www: Unknown svcpart" . $cust_svc->svcpart;

%my $usersvc = $svc_www->usersvc;
%my $svc_acct = '';
%my $email = '';
%if ( $usersvc ) {
%  $svc_acct = qsearchs('svc_acct', { 'svcnum' => $usersvc } )
%    or die "svc_www: Unknown usersvc $usersvc";
%  $email = $svc_acct->email;
%}
%
%my $domain_record = qsearchs('domain_record', { 'recnum' => $svc_www->recnum } )
%  or die "svc_www: Unknown recnum ". $svc_www->recnum;
%
%my $www = $domain_record->zone;
%
%print header('Website View', menubar(
%  ( ( $custnum )
%    ? ( "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
%      )                                                                       
%    : ( "Cancel this (unaudited) website" =>
%          "${p}misc/cancel-unaudited.cgi?$svcnum" )
%  ),
%  "Main menu" => $p,
%)).
%      qq!<A HREF="${p}edit/svc_www.cgi?$svcnum">Edit this information</A><BR>!.
%      ntable("#cccccc"). '<TR><TD>'. ntable("#cccccc",2).
%      qq!<TR><TD ALIGN="right">Service number</TD>!.
%        qq!<TD BGCOLOR="#ffffff">$svcnum</TD></TR>!.
%      qq!<TR><TD ALIGN="right">Website name</TD>!.
%        qq!<TD BGCOLOR="#ffffff"><A HREF="http://$www">$www<A></TD></TR>!;
%if (  $part_svc->part_svc_column('usersvc')->columnflag ne 'F'
%   || $part_svc->part_svc_column('usersvc')->columnvalue !~ /^\s*$/) {
%  print qq!<TR><TD ALIGN="right">Account</TD>!.
%        qq!<TD BGCOLOR="#ffffff">!;
%
%  if ( $usersvc ) {
%    print qq!<A HREF="${p}view/svc_acct.cgi?$usersvc">$email</A>!;
%  } else {
%    print '</i>(none)</i>';
%  }
%
%  print '</TD></TR>';
%}
    <% qq!<TR><TD ALIGN="right">Config lines</TD>! %>
    <% qq!<TD BGCOLOR="#ffffff"><pre>!.$cgi->escapeHTML(join("\n",$svc_www->config))."</pre></TD></TR>" %>
%
%foreach (sort { $a cmp $b } $svc_www->virtual_fields) {
%  print $svc_www->pvf($_)->widget('HTML', 'view', $svc_www->getfield($_)),
%      "\n";
%}
%
%
%print '</TABLE></TD></TR></TABLE>'.
%      '<BR>'. joblisting({'svcnum'=>$svcnum}, 1).
%      '</BODY></HTML>'
%;
%

