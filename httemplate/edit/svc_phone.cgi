<% include( 'elements/svc_Common.html',
               'name'     => 'Phone number',
               'table'    => 'svc_phone',
               'fields'   => [ 'countrycode',
                               { field => 'phonenum',
                                 type  => 'select-did',
                                 label => 'Phone number',
                               },
                               'pin',
                             ],
               'labels'   => {
                               'countrycode' => 'Country code',
                               'phonenum'    => 'Phone number',
                               'pin'         => 'PIN',
                             },
           )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

</%init>
