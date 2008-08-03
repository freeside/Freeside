<% include('elements/svc_Common.html',
              'table'     => 'svc_phone',
              'fields'    => [qw(
                                  countrycode
                                  phonenum
                                  sip_password
                                  pin
                                  phone_name
                             )],
              'labels'    => {
                               'countrycode'  => 'Country code',
                               'phonenum'     => 'Phone number',
                               'sip_password' => 'SIP password',
                               'pin'          => 'PIN',
                               'phone_name'   => 'Name',
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

  my @ilinks = ( qq(<A HREF="${p}search/cdr.html?dst=$number">).
                 'View incoming CDRs</A>' );

  join(' | ', @links ). '<BR>'.
  join(' | ', @ilinks). '<BR>';

};

</%init>
