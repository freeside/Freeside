<% include( 'elements/svc_Common.html',
               'name'     => 'Phone number',
               'table'    => 'svc_phone',
               'fields'   => [qw( countrycode phonenum )], #pin
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
