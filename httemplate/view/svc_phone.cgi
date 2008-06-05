<% include('elements/svc_Common.html',
              'table'     => 'svc_phone',
              'fields'    => [qw( countrycode phonenum pin )],
              'labels'    => {
                               'countrycode' => 'Country code',
                               'phonenum'    => 'Phone number',
                               'pin'         => 'PIN',
                             },
              'html_foot' => $html_foot,
          )
%>
<%init>

my $html_foot = sub {
  my $svc_phone = shift;

  tie my %what, 'Tie::IxHash',
    'pending' => 'NULL',
    'billed'  => 'done',
  ;

  #XXX src & charged party (& default prefix) as per voip_cdr.pm
  #XXX handle toll free too

  my $number = $svc_phone->phonenum;

  #my @links = map {
  #  qq(<A HREF="${p}search/cdr.html?src=$number;freesidestatus=$what{$_}">).
  #  "View $_ CDRs</A>";
  #} keys(%what);
  my @links = map {
    qq(<A HREF="${p}search/cdr.html?charged_party=$number;freesidestatus=$what{$_}">).
    "View $_ CDRs</A>";
  } keys(%what);

  join(' | ', @links). '<BR>';

};

</%init>
