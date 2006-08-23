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
