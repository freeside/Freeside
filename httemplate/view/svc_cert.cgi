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
        '<PRE><FONT STYLE="font-family:monospace">'. "\n". $svc_cert->csr.
        '</FONT></PRE>';
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

        tie my %w, 'Tie::IxHash',
          'subject' => 'Issued to',
          'issuer'  => 'Issued by',
        ;

        my $out = '<TABLE><TR><TD>';

        foreach my $w ( keys %w ) {

          $out .= include('/elements/table-grid.html'). #'<TABLE>'.
                  '<TR><TH COLSPAN=2 BGCOLOR="#cccccc" ALIGN="center">'.
                  $w{$w}. '</TH></TR>';

          my $col = $svc_cert->subj_col;

          my $subj = $hash{$w};
          foreach my $key (keys %$col) { #( keys %$subj ) {
            $out .= "<TR><TD>". $labels{$col->{$key}}.  "</TD>".
                        "<TD>". $subj->{$key}. "</TD></TR>";
          }

          $out .= '</TABLE></TD><TD>';
        }
        $out .= '</TD></TR></TABLE>';

        $out .= '<TABLE>'.
                '<TR><TH ALIGN="right">Serial number</TH>'.
                    "<TD>$hash{serial}</TD></TR>".
                '<TR><TH ALIGN="right">Valid</TH>'.
                    "<TD>$hash{notBefore} - $hash{notAfter}</TD></TR>".
                '</TABLE>';

        my $svcnum = $svc_cert->svcnum;

        if ( $hash{'selfsigned'} ) {
          $out .= qq(<BR> <A HREF="${p}misc/svc_cert-generate.html?action=generate_selfsigned;svcnum=$svcnum">Re-generate self-signed</A>).
                  ' &nbsp; '.
                  include('/elements/popup_link.html', {
                    'action'      => $p."edit/svc_cert/import_certificate.html".
                                     "?svcnum=$svcnum",
                    'label'       => 'Import issued certificate', #link
                    'actionlabel' => 'Import issued certificate', #title
                    #opt
                    'width'       => '544',
                    'height'      => '368',
                    #'color'       => '#ff0000',
                  }).
                  '<BR>';
        }

        $out .= '<PRE><FONT STYLE="font-family:monospace">'.
                $svc_cert->certificate.
                '</FONT><PRE>';

        $out;
      } elsif ( $svc_cert->csr ) {
        my $svcnum = $svc_cert->svcnum;
        qq(<A HREF="${p}misc/svc_cert-generate.html?action=generate_selfsigned;svcnum=$svcnum">Generate self-signed</A>);
      } else {
        '';
      }
    },
  },
  { 'field'=>'cacert',
    'value'=> sub {
      my $svc_cert = shift;
      if ( $svc_cert->cacert ) {

        my %hash = $svc_cert->check_cacert;

        tie my %w, 'Tie::IxHash',
          'subject' => 'Issued to',
          'issuer'  => 'Issued by',
        ;

        my $out = '<TABLE><TR><TD>';

        foreach my $w ( keys %w ) {

          $out .= include('/elements/table-grid.html'). #'<TABLE>'.
                  '<TR><TH COLSPAN=2 BGCOLOR="#cccccc" ALIGN="center">'.
                  $w{$w}. '</TH></TR>';

          my $col = $svc_cert->subj_col;

          my $subj = $hash{$w};
          foreach my $key (keys %$col) { #( keys %$subj ) {
            $out .= "<TR><TD>". $labels{$col->{$key}}.  "</TD>".
                        "<TD>". $subj->{$key}. "</TD></TR>";
          }

          $out .= '</TABLE></TD><TD>';
        }
        $out .= '</TD></TR></TABLE>';

        $out .= '<TABLE>'.
                '<TR><TH ALIGN="right">Serial number</TH>'.
                    "<TD>$hash{serial}</TD></TR>".
                '<TR><TH ALIGN="right">Valid</TH>'.
                    "<TD>$hash{notBefore} - $hash{notAfter}</TD></TR>".
                '</TABLE>';

        $out .= '<PRE><FONT STYLE="font-family:monospace">'.
                $svc_cert->certificate.
                '</FONT><PRE>';

        $out;

      } else {

        my $svcnum = $svc_cert->svcnum;

        include('/elements/popup_link.html', {
          'action'      => $p."edit/svc_cert/import_cacert.html".
                           "?svcnum=$svcnum",
          'label'       => 'Import certificate authority chain',#link
          'actionlabel' => 'Import certificate authority chain',#title
          #opt
          'width'       => '544',
          'height'      => '368',
          #'color'       => '#ff0000',
        }). '&nbsp;(optional)'.
        '<BR>';

      }
    },
  },
);

</%init>
