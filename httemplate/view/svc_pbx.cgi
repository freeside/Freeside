<% include('elements/svc_Common.html',
             'table'     => 'svc_pbx',
             'edit_url'  => $p.'edit/svc_pbx.html?',
             'labels'    => \%labels,
             'html_foot' => $html_foot,
          )
%>
<%init>

my $fields = FS::svc_pbx->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 }
             keys %$fields;

my $html_foot = sub {
  my $svc_pbx = shift;

  ##
  # Extensions
  ##

  my @pbx_extension = sort { $a->extension cmp $b->extension }
                        $svc_pbx->pbx_extension;

  my $extensions = '';
  if ( @pbx_extension ) {

    $extensions .= '<FONT CLASS="fsinnerbox-title">Extensions</FONT>'.
                   include('/elements/table-grid.html');
    my $bgcolor1 = '#eeeeee';
    my $bgcolor2 = '#ffffff';
    my $bgcolor = '';

    #$extensions .= '
    #  <TR>
    #    <TH CLASS="grid" BGCOLOR="#cccccc">Ext</TH>
    #    <TH CLASS="grid" BGCOLOR="#cccccc">Name</TH>
    #  </TR>
    #';

    foreach my $pbx_extension ( @pbx_extension ) {
      if ( $bgcolor eq $bgcolor1 ) {
        $bgcolor = $bgcolor2;
      } else {
        $bgcolor = $bgcolor1;
      }

      $extensions .= qq(
        <TR>
          <TD CLASS="grid" BGCOLOR="$bgcolor">). $pbx_extension->extension. qq(
          <TD CLASS="grid" BGCOLOR="$bgcolor">). $pbx_extension->phone_name. qq(
        </TR>
      );
      
    }

    $extensions .= '</TABLE><BR>';
  }

  ##
  # CDR links
  ##

  tie my %what, 'Tie::IxHash',
    'pending' => 'NULL',
    'billed'  => 'done',
  ;

  #matching as per package def cdr_svc_method
  my $cust_pkg = $svc_pbx->cust_svc->cust_pkg;
  return $extensions unless $cust_pkg;

  my @voip_pkgs =
    grep { $_->plan eq 'voip_cdr' } $cust_pkg->part_pkg->self_and_bill_linked;
  if ( scalar(@voip_pkgs) > 1 ) { 
    warn "multiple voip_cdr packages bundled\n";
    return '';
  } elsif ( !@voip_pkgs ) {
    warn "no voip_cdr packages\n";
  }
  my $voip_pkg = @voip_pkgs[0];

  my $cdr_svc_method = ( $voip_pkg && $voip_pkg->option('cdr_svc_method') )
                       || 'svc_phone.phonenum';
  return $extensions unless $cdr_svc_method =~ /^svc_pbx\.(.*)$/;
  my $field = $1;

  my $search;
  if ( $field eq 'title' ) {
    $search = 'charged_party='. uri_escape($svc_pbx->title);
  } elsif ( $field =~ /^ip\.(\w+)$/ ) {
    $search = "$1_ip_addr=". uri_escape($svc_pbx->title);
  } elsif ( $field eq 'svcnum' ) {
    $search = 'svcnum='. $svc_pbx->svcnum;
  } else {
    warn "unknown cdr_svc_method svc_pbx.$field";
    return $extensions
  }

  my @links = map {
    qq(<A HREF="${p}search/cdr.html?cdrbatchnum=__ALL__;$search;freesidestatus=$what{$_}">).
    "View $_ CDRs</A>";
  } keys(%what);

  ###
  # concatenate & return
  ###

  $extensions.
  join(' | ', @links ). '<BR>';

};

</%init>
