<% include( 'elements/svc_Common.html',
              'table'              => 'svc_dsl',
              'fields'             => \@fields,
              'svc_new_callback'   => $new_cb,
              'svc_edit_callback'  => $edit_cb,
              'svc_error_callback' => $error_cb,
              'html_foot'          => $html_foot,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $ti_fields = FS::svc_dsl->table_info->{'fields'};

my @fields = ();

my $html_foot = sub { "
<SCRIPT TYPE=\"text/javascript\">
  function ikano_loop_type_changed() {
        var loop_type = document.getElementById('loop_type').value;
        var phonenum = document.getElementById('phonenum');
        var gateway_access_number = document.getElementById('gateway_access_number');
        if(loop_type == '0') {
            phonenum.value = '';
            phonenum.disabled = true;        
            gateway_access_number.value = '';
            gateway_access_number.disabled = true;
        } else {
            phonenum.disabled = false;
            gateway_access_number.disabled = false;
        }
  }
</SCRIPT>
"; };

my $edit_cb = sub {
    my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields1,$opt) = @_;
    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export attached to svcpart ".$part_svc->svcpart
        if ( scalar(@exports) > 1 );

    if ( scalar(@exports) == 1 ) {
        my $export = @exports[0];                
        if($export->exporttype eq 'ikano' && $export->import_mode) {
            @fields = ();
        }
        elsif($export->exporttype eq 'ikano') {
            @fields = ( 'password', 'monitored', );

            if ( $svc_x->vendor_qual_id ) {
              push @fields, { field => 'vendor_qual_id',
                              type  => 'hidden',
                              value => $svc_x->vendor_qual_id,
                            };
            } else {
              push @fields, 'vendor_qual_id';
            }

            foreach my $hf (
              grep { $_ !~ /^(password|monitored|vendor_qual_id)$/ }
                keys %$ti_fields
            ) {
              push @fields, {
                field => $hf,
                type  => 'hidden',
                value => $svc_x->$hf,
              };
            }
        }
        # else add any other export-specific stuff here
    }
    else {
        push @fields, qw( first last company phonenum gateway_access_number circuitnum rate_band vpi vci );
    }
};

my $new_cb = sub {
    my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields1,$opt) = @_;
    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export for svcpart ".$part_svc->svcpart
      if ( scalar(@exports) > 1 );
    
    if ( scalar(@exports) == 1 ) {
        my $export = @exports[0];                
        if($export->exporttype eq 'ikano' && $export->import_mode) {
            @fields = ( 'vendor_order_id' );
            return;
        }
    }

    my $cust_main = $cust_pkg->cust_main;

    @fields = (
        { field => 'first',
          value => $cust_main->ship_first ? $cust_main->ship_first
                                          : $cust_main->first,
        },
        { field => 'last',
          value => $cust_main->ship_last ? $cust_main->ship_last
                                         : $cust_main->last,
        },
        { field => 'company',
          value => $cust_pkg->cust_main->ship_company,
          value => $cust_main->ship_company ? $cust_main->ship_company
                                            : $cust_main->company,
        },
    );

    my $vendor_qual_id = '';
    my $qual = '';
    if ( $cgi->param('qualnum') ) {

      $qual =
        qsearchs('qual', { 'qualnum' => scalar($cgi->param('qualnum')) } )
          or die 'unknown qualnum';

      $vendor_qual_id = $qual->vendor_qual_id;

      push @fields, { 'field' => 'qualnum',
                      'type'  => 'hidden',
                      'value' => $qual->qualnum,
                    },
                    { 'field' => 'phonenum',
                      'type'  => 'fixed',
                      'value' => $qual->phonenum,
                    };
    
    } else {

      my $phonenum = $cust_main->ship_daytime ? $cust_main->ship_daytime
                                           : $cust_main->daytime;
      $phonenum =~ s/[^0-9]//g;

      push @fields,
        { field => 'phonenum',
          value => $phonenum,
        };
        { field => 'gateway_access_number',
          value => '',
        };


    }

    if ( scalar(@exports) == 1 ) {
        my $export = @exports[0];                
        if($export->exporttype eq 'ikano') {
            my $ddd = $cust_pkg->start_date;
            $ddd = time unless $ddd;

            my @quals = $export->quals_by_cust_and_pkg($cust_pkg->cust_main->custnum,$cust_pkg->pkgpart);
            my @prequalids;
            my %prequal_labels;
            foreach my $qual ( @quals ) {
                my $prequalid = $qual->vendor_qual_id;
                push @prequalids, $prequalid;
                $prequal_labels{$prequalid} = "$prequalid - qualification #"
                                                            .$qual->qualnum;
            }

            if ( $vendor_qual_id ) {
              splice @fields, -1, 0,
                  { field    => 'loop_type',
                    type     => 'fixed',
                    value    => ( $qual->phonenum ? '' : '0' ),
                    formatted_value => ( $qual->phonenum ? 'Line-share'
                                                         : 'Standalone' ),
                  };
            } else {
              splice @fields, -1, 0,
                  { field    => 'loop_type',
                    type     => 'select',
                    options  => [ '', '0' ],
                    labels   => { '' => 'Line-share', '0', => 'Standalone' },
                    onchange => 'ikano_loop_type_changed',
                  };
            }

            push @fields,
                'password', 
                { field => 'isp_chg', type => 'checkbox', value=>'Y', },
                'isp_prev',
            ;

            if ( $vendor_qual_id ) {
              push @fields,
                { field => 'vendor_qual_id',
                  type  => 'fixed',
                  value => $vendor_qual_id,
                };
            } else {
              push @fields,
                { field    => 'vendor_qual_id', 
                  type     => 'select',
                  options  => \@prequalids,
                  labels   => \%prequal_labels,
                  onchange => 'ikano_vendor_qual_id_changed',
                };
            }

            push @fields,
                { field => 'vendor_order_type', 
                  type  => 'hidden', 
                  value => 'NEW' },
                { field => 'desired_due_date',
                  type  => 'fixed',
                  formatted_value => 
                    time2str($date_format,$ddd),
                  value => $ddd, 
                },
            ;
        }
        # else add any other export-specific stuff here

    } else { # display non-export and non-Ikano fields
        push @fields, qw( rate_band circuitnum vpi vci );
    }
};

my $error_cb = sub {
    my( $cgi ) = @_;
    #my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields,$opt) = @_;
    if ( $cgi->param('svcnum') ) {
      &{ $edit_cb }( @_ );
    } else {
      &{ $new_cb }( @_ );
    }
};

</%init>
