<& elements/svc_Common.html,
     'table'            => 'svc_phone',
     'fields'           => [],
     'begin_callback'   => $begin_callback,
     'svc_new_callback'   => $svc_callback,
     'svc_edit_callback'  => $svc_callback,
     'svc_error_callback' => $svc_callback,
&>
<%init>
my $conf = new FS::Conf;

my $begin_callback = sub {
  my( $cgi, $fields, $opt ) = @_;

  my $bulk = $cgi->param('bulk') ? 1 : 0;

  my $right = $bulk ? 'Bulk provision customer service'
                    :      'Provision customer service';

  die "access denied"
    unless $FS::CurrentUser::CurrentUser->access_right($right);

  push @$fields,
              'countrycode',
              { field    => 'phonenum',
                type     => 'select-did',
                label    => 'Phone number',
                multiple => $bulk,
              },
              { field     => 'sim_imsi',
                type      => 'text',
                size      => 15,
                maxlength => 15,
              };

  push @$fields, { field => 'domsvc',
                   type  => 'select-svc-domain',
                   label => 'Domain',
                 }
    if $conf->exists('svc_phone-domain');

  push @$fields, { field => 'pbxsvc',
                   type  => 'select-svc_pbx',
                   label => 'PBX',
                 };

  if ( $bulk ) {

    push @$fields, { field => 'bulk',
                     type  => 'hidden',
                     value => '1',
                   };

  } else {

    push @$fields,
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
                colspan => 8,
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
              { field   => 'e911_class',
                type    => 'select',
                options => [ keys(%{ FS::svc_phone->e911_classes }) ],
                labels  => FS::svc_phone->e911_classes,
              },
              { field   => 'e911_type',
                type    => 'select',
                options => [ keys(%{ FS::svc_phone->e911_types }) ],
                labels  => FS::svc_phone->e911_types,
              },
              { field => 'custnum', type=> 'hidden' }, #for new cust_locations
    ;
  }

  if ( $conf->exists('svc_phone-lnp') && !$bulk ) {
    push @$fields,
            { value   => 'Number Portability',
	      type    => 'tablebreak-tr-title',
				colspan => 8,
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

  if ( ! $bulk ) {

    push @$fields,
           {
             type    => 'tablebreak-tr-title',
             value   => 'Carrier Information',
             colspan => 8,
           },
           { field => 'sms_carrierid',
             label => 'SMS Carrier',
             type  => 'select-cdr_carrier',
           },
           'sms_account',
           'max_simultaneous',
    ;

  }

}; # begin_callback

# svc_edit_callback / svc_new_callback
my $svc_callback = sub {
  my ($cgi, $svc_x, $part_svc, $cust_pkg, $fields, $opt) = @_;

  push @$fields, {
    field => 'circuit_svcnum',
    type  => 'select-svc_circuit',
    cust_pkg => $cust_pkg,
    part_svc => $part_svc,
  };

  if ( $cust_pkg and not $svc_x->svcnum ) {
    # new service, default to package location
    $svc_x->set('locationnum', $cust_pkg->locationnum);
  }

  if ( not $conf->exists('showpasswords') and $svc_x->svcnum ) {
    $svc_x->sip_password('*HIDDEN*');
  }
};
</%init>
