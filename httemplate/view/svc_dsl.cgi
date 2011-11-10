<% include('elements/svc_Common.html',
            'table'        => 'svc_dsl',
            'labels'       => \%labels,
            'fields'       => \@fields,
            'svc_callback' => $svc_cb,
            'html_foot'    => $html_foot,
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
    my( $cgi,$svc_dsl, $part_svc,$cust_pkg, $fields1,$opt) = @_;

    my @exports = $part_svc->part_export_dsl_pull;
    die "more than one DSL-pulling export attached to svcpart ".$part_svc->svcpart
        if ( scalar(@exports) > 1 );
    
    # if no DSL-pulling exports, then just display everything, which is the
    # default behaviour implemented above
    if ( scalar(@exports) ) {

      my $export = @exports[0];

      @fields = (
        'phonenum',
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
        'company',
      );

      my $status = '';
      if($export->exporttype eq 'ikano') {
          push @fields, qw ( username password isp_chg isp_prev staticips );
          $status = "Ikano " . $svc_dsl->vendor_order_type . " order #"
                  . $svc_dsl->vendor_order_id . " &nbsp; Status: " 
                  . $svc_dsl->vendor_order_status;
      }
      # else add any other export-specific stuff here
   
      $footer = "<B>$status</B>";

    }

    if ( grep $_->can('export_getstatus'), $part_svc->part_export ) {

      $footer .= '<BR><BR>'.
                 include('/elements/popup_link.html', {
                   'action' => $p.'view/svc_dsl_status.html'.
                               '?svcnum='. $svc_dsl->svcnum,
                   'label'  => 'View line status',
                   'width'  => 763,
                   'height' => 256,
                 });

    }

    $footer .= '<BR><BR>'.
               include( '/view/elements/svc_devices.html',
                          'svc_x'   => $svc_dsl,
                          'table'   => 'dsl_device',
                          'no_edit' => 1,
                      );

    my @notes = $svc_dsl->notes;
    if ( @notes ) {

      my $conf = new FS::Conf;
      my $date_format = $conf->config('date_format') || '%m/%d/%Y';

      $footer .=
        "Order Notes<BR>". ntable('#cccccc', 2). #id="dsl_notes"
        '<TR><TH>Date</TH><TH>By</TH><TH>Priority</TH><TH>Note</TH></TR>';

      foreach my $note ( @notes ) {
        $footer .= "<TR>
            <TD>".time2str("$date_format %H:%M",$note->date)."</TD>
            <TD>".$note->by."</TD>
            <TD>". ($note->priority eq 'N' ? 'Normal' : 'High') ."</TD>
            <TD>".$note->note."</TD></TR>";
      }

      $footer .= '</TABLE>';

    }
};
</%init>
