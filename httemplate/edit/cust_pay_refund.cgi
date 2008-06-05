<% include('elements/ApplicationCommon.html',
     'form_action' => 'process/cust_pay_refund.cgi',
     'src_table'   => 'cust_pay',
     'src_thing'   => 'payment',
     'dst_table'   => 'cust_refund',
     'dst_thing'   => 'refund',
   )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply payment');

</%init>
