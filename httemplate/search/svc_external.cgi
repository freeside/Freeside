%die "access denied"
%  unless $FS::CurrentUser::CurrentUser->access_right('List services');
%
%my $conf = new FS::Conf;
%
%my @svc_external = ();
%my @h_svc_external = ();
%my $sortby=\*svcnum_sort;
%if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {
%
%  @svc_external=qsearch('svc_external',{});
%
%  if ( $cgi->param('magic') eq 'unlinked' ) {
%    @svc_external = grep { qsearchs('cust_svc', {
%                                                  'svcnum' => $_->svcnum,
%                                                  'pkgnum' => '',
%                                                }
%                                   )
%                         }
%		     @svc_external;
%  }
%
%  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
%    my $sortby = $1;
%    if ( $sortby eq 'id' ) {
%      $sortby = \*id_sort;
%    }
%  }
%
%} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
%
%  @svc_external =
%    qsearch( 'svc_external', {}, '',
%               " WHERE $1 = ( SELECT svcpart FROM cust_svc ".
%               "              WHERE cust_svc.svcnum = svc_external.svcnum ) "
%    );
%
%} elsif ( $cgi->param('title') =~ /^(.*)$/ ) {
%  $sortby=\*id_sort;
%  @svc_external=qsearch('svc_external',{ title => $1 });
%  if( $cgi->param('history') == 1 ) {
%    @h_svc_external=qsearch('h_svc_external',{ title => $1 });
%  }
%} elsif ( $cgi->param('id') =~ /^([\w\-\.]+)$/ ) {
%  my $id = $1;
%  @svc_external = qsearchs('svc_external',{'id'=>$id});
%}
%
%if ( scalar(@svc_external) == 1 ) {
%
%  
<% $cgi->redirect(popurl(2). "view/svc_external.cgi?". $svc_external[0]->svcnum) %>
%
%
%} elsif ( scalar(@svc_external) == 0 ) {
%
%  
<% include('/elements/header.html', 'External Search Results' ) %>

  No matching external services found
% } else {
%
%  
<% include('/elements/header.html', 'External Search Results', '') %>

    <% scalar(@svc_external) %> matching external services found
    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
      <TR>
        <TH>Service #</TH>
        <TH><% FS::Msgcat::_gettext('svc_external-id') || 'External&nbsp;ID' %></TH>
        <TH><% FS::Msgcat::_gettext('svc_external-title') || 'Title' %></TH>
      </TR>
%
%  foreach my $svc_external (
%    sort $sortby (@svc_external)
%  ) {
%    my($svcnum, $id, $title)=(
%      $svc_external->svcnum,
%      $svc_external->id,
%      $svc_external->title,
%    );
%
%    my $rowspan = 1;
%
%    print <<END;
%    <TR>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$svcnum</A></TD>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$id</A></TD>
%      <TD ROWSPAN=$rowspan><A HREF="${p}view/svc_external.cgi?$svcnum">$title</A></TD>
%END
%
%    #print @rows;
%    print "</TR>";
%
%  }
%  if( scalar(@h_svc_external) > 0 ) {
%    print <<HTML;
%    </TABLE>
%    <TABLE BORDER=4 CELLSPACING=0 CELLPADDING=0>
%      <TR>
%        <TH>Freeside ID</TH>
%        <TH>Service #</TH>
%        <TH>Title</TH>
%        <TH>Date</TH>
%      </TR>
%HTML
%
%    foreach my $h_svc ( @h_svc_external ) {
%        my($svcnum, $id, $title, $user, $date)=(
%            $h_svc->svcnum,
%            $h_svc->id,
%            $h_svc->title,
%            $h_svc->history_user,
%            $h_svc->history_date,
%        );
%        my $rowspan = 1;
%        my ($h_cust_svc) = qsearchs( 'h_cust_svc', {
%            svcnum  =>  $svcnum,
%        });
%        my $cust_pkg = qsearchs( 'cust_pkg', {
%            pkgnum  =>  $h_cust_svc->pkgnum,
%        });
%        my $custnum = $cust_pkg->custnum;
%
%        print <<END;
%        <TR>
%          <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_main.cgi?$custnum">$custnum</A></TD>
%          <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_main.cgi?$custnum">$svcnum</A></TD>
%          <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_main.cgi?$custnum">$title</A></TD>
%          <TD ROWSPAN=$rowspan><A HREF="${p}view/cust_main.cgi?$custnum">$date</A></TD>
%        </TR>
%END
%    }
%  }
%
%  print <<END;
%    </TABLE>
%  </BODY>
%</HTML>
%END
%
%}
%
%sub svcnum_sort {
%  $a->getfield('svcnum') <=> $b->getfield('svcnum');
%}
%
%sub id_sort {
%  $a->getfield('id') <=> $b->getfield('id');
%}
%
%

