<% include('elements/svc_Common.html',
             'table'     => 'svc_cert',
             'labels'    => \%labels,
             #'html_foot' => $html_foot,
             'fields' => \@fields,
          )
%>
<%init>

my $fields = FS::svc_cert->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 }
             keys %$fields;

my @fields = (
  { field=>'privatekey',
    value=> sub {
      my $svc_cert = shift;
      if ( $svc_cert->privatekey && $svc_cert->check_privatekey ) {
        '<FONT COLOR="#33ff33">Verification OK</FONT>';
      } elsif ( $svc_cert->privatekey ) {
        '<FONT COLOR="#ff0000">Verification error</FONT>';
      } else {
        '<I>(none)</I>';
      }
    },
  },
  qw( organization organization_unit city state country cert_contact )
);

</%init>
