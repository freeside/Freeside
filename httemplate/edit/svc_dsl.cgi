<% include( 'elements/svc_Common.html',
            'table'   	=> 'svc_dsl',
	    'fields'	=> \@fields,
	    'svc_new_callback' => $new_cb,
	    'svc_edit_callback' => $edit_cb,
	    'html_foot' => $html_foot,
	  )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $ti_fields = FS::svc_dsl->table_info->{'fields'};

my @fields = ();

my $html_foot = sub {
    return "
<SCRIPT TYPE=\"text/javascript\">
  function ikano_loop_type_changed() {
	var loop_type = document.getElementById('loop_type').value;
	var phonenum = document.getElementById('phonenum');
	if(loop_type == '0') {
	    phonenum.value = '';
	    phonenum.disabled = true;	
	}
	else phonenum.disabled = false;
  }
</SCRIPT>";
};

my $edit_cb = sub {
    my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields1,$opt) = @_;
    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export attached to svcpart ".$part_svc->svcpart
	if ( scalar(@exports) > 1 );

    if ( scalar(@exports) == 1 ) {
	my $export = @exports[0];		
	if($export->exporttype eq 'ikano') {
	    @fields = ( 'password', 'monitored', );

	    foreach my $hf ( keys %$ti_fields ) {
		push @fields, {
		    field => $hf,
		    type => 'hidden',
		    value => $svc_x->$hf,
		} unless ( $hf eq 'password' || $hf eq 'monitored' );
	    }
	}
	# else add any other export-specific stuff here
    }
    else {
	# XXX allow editing everything
    }
};

my $new_cb = sub {
    my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields1,$opt) = @_;
    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export attached to svcpart ".$part_svc->svcpart
	if ( scalar(@exports) > 1 );

    if ( scalar(@exports) == 1 ) {
	my $cust_main = $cust_pkg->cust_main;
	my $defsvctn = $cust_main->ship_daytime ? $cust_main->ship_daytime
						: $cust_main->daytime;
	$defsvctn =~ s/[^0-9]//g;

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
	    { field => 'phonenum',
	      value => $defsvctn,
	    },
	);

	my $export = @exports[0];		
	if($export->exporttype eq 'ikano') {
	    $cgi->param('vendor_qual_id') =~ /^(\d+)$/ 
		or die 'unparsable vendor_qual_id';
	    my $vendor_qual_id = $1;

	    die "no start date set on customer package" if !$cust_pkg->start_date;

	    my @addl_fields = ( 
		{ field => 'loop_type',
		  type => 'select',
		  options => [ '', '0' ],
		  labels => { '' => 'Line-share', '0', => 'Standalone' },
		  onchange => 'ikano_loop_type_changed',
		},
		'password', 
		{ field => 'isp_chg', type => 'checkbox', },
		'isp_prev',
		{ field => 'vendor_qual_id', 
		  type => 'fixed', 
		  value => $vendor_qual_id,  },
		{ field => 'vendor_order_type', 
		  type => 'hidden', 
		  value => 'NEW' },
		{ field => 'desired_due_date',
		  type => 'fixed',
		  formatted_value => 
		    time2str($date_format,$cust_pkg->start_date),
		  value => $cust_pkg->start_date, 
		},
	    );
	    push @fields, @addl_fields;
	}
	# else add any other export-specific stuff here
    }
    else {
	# XXX display everything when no exports attached
    }
};
</%init>
