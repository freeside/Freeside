<% include('elements/ApplicationCommon.html',
     'error_redirect' => 'cust_credit_bill.cgi',
     'src_table'      => 'cust_credit',
     'src_thing'      => 'credit',
     'link_table'     => 'cust_credit_refund',
   )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply credit');

</%init>
