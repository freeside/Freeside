<% include('elements/svc_Common.html',
            'table'     => 'svc_dsl',
            'labels'    => \%labels,
            'fields' => \@fields,
	    'svc_callback' => $svc_cb,
	    'html_foot' => $html_foot,
          )
%>
<%init>
my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

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

    $opt->{'disable_unprovision'} = 1;
    my $exporttype = @exports[0]->exporttype;	

    # XXX: AJAX auto-pull
	
    @fields = qw( svctn first last company username password );

    if($exporttype eq 'ikano') {
	push @fields, 'isp_chg';
	push @fields, 'isp_prev';
	push @fields, 'staticips';
    }
    else {
	# XXX
    }
    
    # hack against "can't use string ... as a subroutine ref while 'strict refs' in use"
    my $statusSub = \&{'FS::part_export::'.$exporttype.'::status_line'};
    my $statusLine = &$statusSub($svc_x,$date_format,"<BR>");
    
    $footer = "<B>$statusLine</B>";

    # XXX: notes
};
</%init>
