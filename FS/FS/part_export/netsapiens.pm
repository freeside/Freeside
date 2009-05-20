package FS::part_export::netsapiens;

use vars qw(@ISA %info);
use URI;
use MIME::Base64;
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'         => { label=>'NetSapiens tac2 API username' },
  'password'      => { label=>'NetSapiens tac2 API password' },
  'url'           => { label=>'NetSapiens tac2 URL' },
  'domain'        => { label=>'NetSapiens Domain' },
;

%info = (
  'svc'      => 'svc_phone',
  'desc'     => 'Provision phone numbers to NetSapiens',
  'options'  => \%options,
  'notes'    => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/REST-Client">REST::Client</a>
from CPAN.
END
);

sub rebless { shift; }

sub ns_command {
  my( $self, $method, $command ) = splice(@_,0,3);

  eval 'use REST::Client';
  die $@ if $@;

  my $ns = new REST::Client 'host'=>$self->option('url');

  my @args = ( $command );

  if ( $method eq 'PUT' ) {
    my $content = $method eq 'PUT' ? $ns->buildQuery( { @_ } ) : '';
    $content =~ s/^\?//;
    push @args, $content;
  }

  my $auth =
    encode_base64( $self->option('login'). ':'. $self->option('password') );
  push @args, { 'Authorization' => "Basic $auth" };

  $ns->$method( @args );
  $ns;
}

sub ns_subscriber {
  my($self, $svc_phone) = (shift, shift);

  my $domain = $self->option('domain');
  my $phonenum = $svc_phone->phonenum;

  "/domains_config/$domain/subscriber_config/$phonenum";
}

sub ns_create_or_update {
  my($self, $svc_phone, $dial_policy) = (shift, shift, shift);

  my $domain = $self->option('domain');
  my $phonenum = $svc_phone->phonenum;

  my( $firstname, $lastname );
  if ( $svc_phone->phone_name =~ /^\s*(\S+)\s+(\S.*\S)\s*$/ ) {
    $firstname = $1;
    $lastname  = $2;
  } else {
    #deal w/unaudited netsapiens services?
    my $cust_main = $svc_phone->cust_svc->cust_pkg->cust_main;
    $firstname = $cust_main->get('first');
    $lastname  = $cust_main->get('last');
  }

  my $ns = $self->ns_command( 'PUT', $self->ns_subscriber($svc_phone), 
                                'subscriber_login' => $phonenum.'@'.$domain,
                                'firstname'        => $firstname,
                                'lastname'         => $lastname,
                                'subscriber_pin'   => $svc_phone->pin,
                                'dial_plan'        => 'Default', #config?
                                'dial_policy'      => $dial_policy,
                            );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  '';
}

sub ns_delete {
  my($self, $svc_phone) = (shift, shift);

  my $ns = $self->ns_command( 'DELETE', $self->ns_subscriber($svc_phone) );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  '';

}

sub ns_parse_response {
  my( $self, $content ) = ( shift, shift );

  #try to screen-scrape something useful
  tie my %hash, Tie::IxHash;
  while ( $content =~ s/^.*?<p>\s*<b>(.+?)<\/b>\s*(.+?)\s*<\/p>//is ) {
    ( $hash{$1} = $2 ) =~ s/^\s*<(\w+)>(.+?)<\/\1>/$2/is;
  }

  %hash;
}

sub _export_insert {
  my($self, $svc_phone) = (shift, shift);
  $self->ns_create_or_update($svc_phone, 'Permit All');
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change phonenum with NetSapiens (unprovision and reprovision?)"
    if $old->phonenum ne $new->phonenum;
  $self->_export_insert($new);
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  $self->ns_delete($svc_phone);
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  $self->ns_create_or_udpate($svc_phone, 'Deny');
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #$self->ns_create_or_update($svc_phone, 'Permit All');
  $self->_export_insert($svc_phone);
}

sub export_links {
  my($self, $svc_phone, $arrayref) = (shift, shift, shift);
  #push @$arrayref, qq!<A HREF="http://example.com/~!. $svc_phone->username.
  #                 qq!">!. $svc_phone->username. qq!</A>!;
  '';
}

1;
