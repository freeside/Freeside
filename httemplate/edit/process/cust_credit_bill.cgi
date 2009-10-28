<% include('elements/ApplicationCommon.html',
     'error_redirect' => 'cust_credit_bill.cgi',
     'src_table'      => 'cust_credit',
     'src_thing'      => 'credit',
     'link_table'     => 'cust_credit_bill',
   )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply credit');

if ( $cgi->param('src_amount') ) {
  die "access denied"
    unless ( $FS::CurrentUser::CurrentUser->access_right('Post credit') &&
           $FS::CurrentUser::CurrentUser->access_right('Delete credit') );
}

</%init>
