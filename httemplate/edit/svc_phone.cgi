<% include( 'elements/svc_Common.html',
               'table'    => 'svc_phone',
               'fields'   => \@fields,
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
	      'forwarddst',
	      'email',

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

if ( $conf->exists('svc_phone-lnp') ) {
    push @fields,
            { value   => 'Number Portability',
	      type    => 'tablebreak-tr-title',
				colspan => 7,
            },
	    {	field => 'lnp_status',
		type => 'select-lnp_status',
	    },
	    'lnp_reject_reason',
	    {	field => 'portable',
		type => 'checkbox',
	    },
            'lrn',
	    {	field => 'lnp_desired_due_date',
		type => 'input-date-field',
	    },
	    {	field => 'lnp_due_date',
		type => 'input-date-field',
		noinit => 1,
	    },
            'lnp_other_provider',
            'lnp_other_provider_account',
;
}

</%init>
