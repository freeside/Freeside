<% include('elements/ApplicationCommon.html',
     'error_redirect' => 'cust_bill_pay.cgi',
     'src_table'      => 'cust_pay',
     'src_thing'      => 'payment',
     'link_table'     => 'cust_pay_refund',
   )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply payment');

</%init>
