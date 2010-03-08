<% include( 'elements/svc_Common.html',
               'name'     => 'Phone number',
               'table'    => 'svc_phone',
               'fields'   => \@fields,
               'labels'   => {
                               'countrycode'  => 'Country code',
                               'phonenum'     => 'Phone number',
                               'domsvc'       => 'Domain',
                               'sip_password' => 'SIP password',
                               'pin'          => 'Voicemail PIN',
                               'phone_name'   => 'Name',
                               'pbxsvc'       => 'PBX',
                             },
           )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;

my @fields = ( 'countrycode',
               { field => 'phonenum',
                 type  => 'select-did',
                 label => 'Phone number',
               },
             );

push @fields, { field => 'domsvc',
                type  => 'select-svc-domain',
                label => 'Domain',
              }
  if $conf->exists('svc_phone-domain');

push @fields, { field => 'pbxsvc',
                type  => 'select-svc_pbx',
                label => 'PBX',
              },
              'sip_password',
              'pin',
              'phone_name',
;

</%init>
