% die "access denied"
%   unless $FS::CurrentUser::CurrentUser->access_right('View customer services');
%
%my $conf = new FS::Conf;
%
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/;
%my $svcnum = $1;
%my $svc_forward = qsearchs({
%  'select'    => 'svc_forward.*',
%  'table'     => 'svc_forward',
%  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
%                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
%                 ' LEFT JOIN cust_main USING ( custnum ) ',
%  'hashref'   => {'svcnum'=>$svcnum},
%  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
%});
%die "Unknown svcnum" unless $svc_forward;
%
%my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
%my $pkgnum = $cust_svc->getfield('pkgnum');
%my($cust_pkg, $custnum);
%if ($pkgnum) {
%  $cust_pkg=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
%  $custnum=$cust_pkg->getfield('custnum');
%} else {
%  $cust_pkg = '';
%  $custnum = '';
%}
%
%my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } )
%  or die "Unknown svcpart";
%
%print header('Mail Forward View', menubar(
%  ( ( $pkgnum || $custnum )
%    ? ( "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
%      )
%    : ( "Cancel this (unaudited) mail forward" =>
%          "${p}misc/cancel-unaudited.cgi?$svcnum" )
%  )
%));
%
%my($srcsvc,$dstsvc,$dst) = (
%  $svc_forward->srcsvc,
%  $svc_forward->dstsvc,
%  $svc_forward->dst,
%);
%my $src = $svc_forward->dbdef_table->column('src') ? $svc_forward->src : '';
%
%my $svc = $part_svc->svc;
%
%my $source;
%if ($srcsvc) {
%  my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$srcsvc})
%    or die "Corrupted database: no svc_acct.svcnum matching srcsvc $srcsvc";
%  $source = $svc_acct->email;
%} else {
%  $source = $src;
%}
%
%my $destination;
%if ($dstsvc) {
%  my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$dstsvc})
%    or die "Corrupted database: no svc_acct.svcnum matching dstsvc $dstsvc";
%  $destination = $svc_acct->email;
%} else {
%  $destination = $dst;
%}
%
%print qq!<A HREF="${p}edit/svc_forward.cgi?$svcnum">Edit this information</A>!.
%      ntable("#cccccc",2).
%      '<TR><TD ALIGN="right">Service number</TD>'.
%        qq!<TD BGCOLOR="#ffffff">$svcnum</TD></TR>!.
%      '<TR><TD ALIGN="right">Service</TD>'.
%        qq!<TD BGCOLOR="#ffffff">$svc</TD></TR>!.
%      qq!<TR><TD ALIGN="right">Email to</TD>!.
%        qq!<TD BGCOLOR="#ffffff">$source</TD></TR>!.
%      qq!<TR><TD ALIGN="right">Forwards to </TD>!.
%        qq!<TD BGCOLOR="#ffffff">$destination</TD></TR>!;
%
%foreach (sort { $a cmp $b } $svc_forward->virtual_fields) {
%  print $svc_forward->pvf($_)->widget('HTML', 'view', $svc_forward->getfield($_)),
%      "\n";
%}
%
%print qq!  </TABLE>!.
%      '<BR>'. joblisting({'svcnum'=>$svcnum}, 1).
%      '</BODY></HTML>'
%;
%
%

