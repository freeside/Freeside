package FS::part_export::http_status;
use base qw( FS::part_export );

use strict;
use warnings;
use vars qw( %info );
use LWP::UserAgent;
use HTTP::Request::Common;

tie my %options, 'Tie::IxHash',
  'url' => { label => 'URL', },
  #'user'     => { label => 'Username', default=>'' },
  #'password' => { label => 'Password', default => '' },
;

%info = (
  'svc'     => 'svc_dsl',
  'desc'    => 'Retrieve status information via HTTP or HTTPS',
  'options' => \%options,
  'notes'   => <<'END'
Fields from the service can be substituted in the URL as $field.
END
);

sub rebless { shift; }

sub export_getstatus {
  my( $self, $svc_x, $htmlref, $hashref ) = @_;

  my $url;
  my $urlopt = $self->option('url');
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_x->getfield($_) foreach $svc_x->fields;
    if ( $svc_x->table eq 'svc_dsl' ) {
      ${$_} = $svc_x->$_() foreach (qw( gateway_access_or_phonenum ));
    }

    $url = eval(qq("$urlopt"));
  }

  my $req = HTTP::Request::Common::GET( $url );
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($req);

  $$htmlref = $response->is_error ? $response->error_as_HTML
                                  : $response->content;

  #hash data note yet implemented for this status export

}

1;
