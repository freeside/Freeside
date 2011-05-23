<& elements/ApplicationCommon.html,
     'form_action' => 'process/cust_bill_pay.cgi',
     'src_table'   => 'cust_pay',
     'src_thing'   => emt('payment'),
     'dst_table'   => 'cust_bill',
     'dst_thing'   => emt('invoice'),
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply payment');

</%init>
