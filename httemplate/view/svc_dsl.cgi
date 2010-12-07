<% include('elements/svc_Common.html',
            'table'     => 'svc_dsl',
            'labels'    => \%labels,
            'fields' => \@fields,
	    'svc_callback' => $svc_cb,
	    'html_foot' => $html_foot,
          )
%>
<%init>

# XXX: AJAX auto-pull

my $fields = FS::svc_dsl->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;
my @fields = keys %$fields;

my $footer;

my $html_foot = sub {
    return $footer;
};

my $svc_cb = sub {
    my( $cgi,$svc_x, $part_svc,$cust_pkg, $fields1,$opt) = @_;

    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export attached to svcpart ".$part_svc->svcpart
	if ( scalar(@exports) > 1 );
    
    # if no DSL-pulling exports, then just display everything, which is the
    # default behaviour implemented above
    return if ( scalar(@exports) == 0 );

    my $export = @exports[0];

    @fields = ( 'phonenum',
	    { field => 'loop_type', 
	      value => 'FS::part_export::'.$export->exporttype.'::loop_type_long'
	    },
	    { field => 'desired_due_date', type => 'date', },
	    { field => 'due_date', type => 'date', },
	    { field => 'pushed', type => 'datetime', },
	    { field => 'monitored', type => 'checkbox', },
	    { field => 'last_pull', type => 'datetime', },
	    'first',
	    'last',
	    'company'  );

    my $status = '';
    if($export->exporttype eq 'ikano') {
	push @fields, qw ( username password isp_chg isp_prev staticips );
	$status = "Ikano " . $svc_x->vendor_order_type . " order #"
		. $svc_x->vendor_order_id . " &nbsp; Status: " 
		. $svc_x->vendor_order_status;
    }
    # else add any other export-specific stuff here
   
    $footer = "<B>$status</B>";
    $footer .= "<BR><BR><BR><B>Order Notes:</B><BR>".$export->notes_html($svc_x);
};
</%init>
