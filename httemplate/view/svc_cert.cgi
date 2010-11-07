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
  qw( common_name organization organization_unit city state country cert_contact
    ),
  { 'field'=>'csr',
    'value'=> sub {
      my $svc_cert = shift;
      if ( $svc_cert->csr ) { #display the subject etc?
        '<FONT STYLE="font-family:monospace"><PRE>'. $svc_cert->csr.
        '</PRE></FONT>';
      } elsif ( $svc_cert->common_name ) {
        my $svcnum = $svc_cert->svcnum;
        qq(<A HREF="${p}misc/svc_cert-generate.html?action=generate_csr;svcnum=$svcnum">Generate</A>);
      } else {
        '';
      }
    },
  },
  { 'field'=>'certificate',
    'value'=> sub {
      my $svc_cert = shift;
      if ( $svc_cert->certificate ) {

        my %hash = $svc_cert->check_certificate;
        my $out = '<TABLE>'; #XXX better formatting
        foreach my $key ( keys %hash ) {
          $out .= "<TR><TD>$key</TD><TD>$hash{$key}</TD></TR>";
        }
        $out .= '</TABLE>';

        $out .= '<FONT STYLE="font-family:monospace"><PRE>'.
                $svc_cert->certificate.
                '</PRE></FONT>';
        $out;
      } elsif ( $svc_cert->csr ) {
        my $svcnum = $svc_cert->svcnum;
        qq(<A HREF="${p}misc/svc_cert-generate.html?action=generate_selfsigned;svcnum=$svcnum">Generate self-signed</A>);
      } else {
        '';
      }
    },
  },
);

</%init>
