<% include('elements/svc_Common.html',
              'table'     => 'svc_phone',
              'fields'    => \@fields,
	      'labels'    => \%labels,
              'html_foot' => $html_foot,
          )
%>
<%init>

my $conf = new FS::Conf;
my $countrydefault = $conf->config('countrydefault') || 'US';

my $fields = FS::svc_phone->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;

my @fields = qw( countrycode phonenum );
push @fields, 'domain' if $conf->exists('svc_phone-domain');
push @fields, qw( pbx_title sip_password pin phone_name );

if ( $conf->exists('svc_phone-lnp') ) {
push @fields, 'lnp_status',
	    'lnp_reject_reason',
	    { field => 'portable', type => 'checkbox', },
	    'lrn',
	    { field => 'lnp_desired_due_date', type => 'date', },
	    { field => 'lnp_due_date', type => 'date', },
	    'lnp_other_provider',
	    'lnp_other_provider_account';
}

my $html_foot = sub {
  my $svc_phone = shift;

  ###
  # E911 Info
  ###

  my $e911 = 
    'E911 Information'.
    &ntable("#cccccc"). '<TR><TD>'. ntable("#cccccc",2).
      '<TR><TD>Location</TD>'.
      '<TD BGCOLOR="#FFFFFF">'.
        $svc_phone->location_label( 'join_string'     => '<BR>',
                                    'double_space'    => ' &nbsp; ',
                                    'escape_function' => \&encode_entities,
                                    'countrydefault'  => $countrydefault,
                                  ).
      '</TD></TR>'.
    '</TABLE></TD></TR></TABLE>'.
    '<BR>'
  ;

  ###
  # Devices
  ###

  my $devices = '';

  my $sth = dbh->prepare("SELECT COUNT(*) FROM part_device") #WHERE disabled = '' OR disabled IS NULL;");
    or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  my $num_part_device = $sth->fetchrow_arrayref->[0];

  my @phone_device = $svc_phone->phone_device;
  if ( @phone_device || $num_part_device ) {
    my $svcnum = $svc_phone->svcnum;
    $devices .=
      qq[Devices (<A HREF="${p}edit/phone_device.html?svcnum=$svcnum">Add device</A>)<BR>];
    if ( @phone_device ) {

      $devices .= qq!
        <SCRIPT>
          function areyousure(href) {
           if (confirm("Are you sure you want to delete this device?") == true)
             window.location.href = href;
          }
        </SCRIPT>
      !;


      $devices .= 
        include('/elements/table-grid.html').
          '<TR>'.
            '<TH CLASS="grid" BGCOLOR="#cccccc">Type</TH>'.
            '<TH CLASS="grid" BGCOLOR="#cccccc">MAC Addr</TH>'.
            '<TH CLASS="grid" BGCOLOR="#cccccc"></TH>'.
            '<TH CLASS="grid" BGCOLOR="#cccccc"></TH>'.
          '</TR>';
      my $bgcolor1 = '#eeeeee';
      my $bgcolor2 = '#ffffff';
      my $bgcolor = '';

      foreach my $phone_device ( @phone_device ) {

        if ( $bgcolor eq $bgcolor1 ) {
          $bgcolor = $bgcolor2;
        } else {
          $bgcolor = $bgcolor1;
        }
        my $td = qq(<TD CLASS="grid" BGCOLOR="$bgcolor">);

        my $devicenum = $phone_device->devicenum;
        my $export_links = join( '<BR>', @{ $phone_device->export_links } );

        $devices .= '<TR>'.
                      $td. $phone_device->part_device->devicename. '</TD>'.
                      $td. $phone_device->mac_addr. '</TD>'.
                      $td. $export_links. '</TD>'.
                      "$td( ".
                        qq(<A HREF="${p}edit/phone_device.html?$devicenum">edit</A> | ).
                        qq(<A HREF="javascript:areyousure('${p}misc/delete-phone_device.html?$devicenum')">delete</A>).
                      ' )</TD>'.
                    '</TR>';
      }
      $devices .= '</TABLE><BR>';
    }
    $devices .= '<BR>';
  }

  ##
  # CDR links
  ##

  tie my %what, 'Tie::IxHash',
    'pending' => 'NULL',
    'billed'  => 'done',
  ;

  my $number = $svc_phone->phonenum;
  $number = $svc_phone->countrycode. $number
    unless $svc_phone->countrycode eq '1';

  #src & charged party as per voip_cdr.pm
  my $search;
  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  if ( $cust_pkg && $cust_pkg->part_pkg->option('disable_src') ) {
    $search = "charged_party=$number";
  } else {
    $search = "charged_party_or_src=$number";
  }

  #XXX default prefix as per voip_cdr.pm
  #XXX handle toll free too

  #my @links = map {
  #  qq(<A HREF="${p}search/cdr.html?src=$number;freesidestatus=$what{$_}">).
  #  "View $_ CDRs</A>";
  #} keys(%what);
  my @links = map {
    qq(<A HREF="${p}search/cdr.html?cdrbatchnum=__ALL__;$search;freesidestatus=$what{$_}">).
    "View $_ CDRs</A>";
  } keys(%what);

  my @ilinks = ( qq(<A HREF="${p}search/cdr.html?cdrbatchnum=__ALL__;dst=$number">).
                 'View incoming CDRs</A>' );

  ###
  # concatenate & return
  ###

  $e911.
  $devices.
  join(' | ', @links ). '<BR>'.
  join(' | ', @ilinks). '<BR>';

};

</%init>
