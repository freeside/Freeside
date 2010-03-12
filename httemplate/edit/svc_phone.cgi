<% include( 'elements/svc_Common.html',
               'table'    => 'svc_phone',
               'fields'   => \@fields,
               'labels'   => {
                               'svcnum'       => 'Service',
                               'countrycode'  => 'Country code',
                               'phonenum'     => 'Phone number',
                               'domsvc'       => 'Domain',
                               'sip_password' => 'SIP password',
                               'pin'          => 'Voicemail PIN',
                               'phone_name'   => 'Name',
                               'pbxsvc'       => 'PBX',
                               'locationnum'  => 'E911 location',
                             },
               'svc_new_callback' => sub {
                 my( $cgi, $svc_x, $part_svc, $cust_pkg, $fields, $opt ) = @_;
                 $svc_x->locationnum($cust_pkg->locationnum) if $cust_pkg;
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
              { field => 'phone_name',
                type  => 'text',
                maxlength => $conf->config('svc_phone-phone_name-max_length'),
              },

              { value   => 'E911 Information',
                type    => 'tablebreak-tr-title',
                colspan => 7,
              },
              { field => 'locationnum',
                type  => 'select-cust_location',
                label => 'E911 location',
                include_opt_callback => sub {
                  my $svc_phone = shift;
                  my $pkgnum =  $svc_phone->get('pkgnum')
                             || $cgi->param('pkgnum')
                             || $svc_phone->cust_svc->pkgnum; #hua?
                               #cross agent location exposure?  sheesh
                  my $cust_pkg = qsearchs('cust_pkg', {'pkgnum' => $pkgnum});
                  my $cust_main = $cust_pkg ? $cust_pkg->cust_main : '';
                  ( 'no_bold'   => 1,
                    'cust_pkg'  => $cust_pkg,
                    'cust_main' => $cust_main,
                  );
                },
              },
              { field => 'custnum', type=> 'hidden' }, #for new cust_locations
;


</%init>
