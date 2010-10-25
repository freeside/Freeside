<% include('elements/svc_Common.html',
             'table'     => 'svc_pbx',
	     'edit_url'  => $p."edit/svc_Common.html?svcdb=svc_pbx;svcnum=",
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
  # CDR links
  ##

  tie my %what, 'Tie::IxHash',
    'pending' => 'NULL',
    'billed'  => 'done',
  ;

  #matching as per package def cdr_svc_method
  my $cust_pkg = $svc_pbx->cust_svc->cust_pkg;
  return '' unless $cust_pkg;

  my @voip_pkgs =
    grep { $_->plan eq 'voip_cdr' } $cust_pkg->part_pkg->self_and_bill_linked;
  if ( scalar(@voip_pkgs) > 1 ) { 
    warn "multiple voip_cdr packages bundled\n";
    return '';
  } elsif ( !@voip_pkgs ) {
    warn "no voip_cdr packages\n";
  }
  my $voip_pkg = @voip_pkgs[0];

  my $cdr_svc_method = $voip_pkg->option('cdr_svc_method')
                       || 'svc_phone.phonenum';
  return '' unless $cdr_svc_method =~ /^svc_pbx\.(\w+)$/;
  my $field = $1;

  my $search;
  if ( $field eq 'title' ) {
    $search = 'charged_party='. uri_escape($svc_pbx->title);
  } elsif ( $field eq 'svcnum' ) {
    $search = 'svcnum='. $svc_pbx->svcnum;
  } else {
    warn "unknown cdr_svc_method svc_pbx.$field";
    return '';
  }

  my @links = map {
    qq(<A HREF="${p}search/cdr.html?cdrbatchnum=__ALL__;$search;freesidestatus=$what{$_}">).
    "View $_ CDRs</A>";
  } keys(%what);

  ###
  # concatenate & return
  ###

  join(' | ', @links ). '<BR>';

};

</%init>
