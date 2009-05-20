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
  my( $self, $method, $command, @args ) = @_;

  eval 'use REST::Client';
  die $@ if $@;

  my $ns = new REST::Client 'host'=>$self->option('url');

  my $content = $method eq 'PUT' ? $ns->buildQuery( { @args } ) : '';
  $content =~ s/^\?//;

  warn $content;

  my $auth =
    encode_base64( $self->option('login'). ':'. $self->option('password') );

  $ns->$method( $command, $content, { 'Authorization' => "Basic $auth" } );

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
                                'firstname'        => $firstname, #4?
                                'lastname'         => $lastname,  #5?
                                'subscriber_pin'   => $svc_phone->pin, #6?
                                'dial_plan'        => 'Default',    #config? #7?
                                'dial_policy'      => $dial_policy, #8?
#no_answer_timeout30   
#  simultaneous_ringyes   
#  gmt_offset-8   
#  aor_schemesip:   
#  do_not_disturbyes   
#  email_vmail   
#  data_limit0   
#  screen   
#  last_update2008-10-01 12:19:01.0   
#  domain_diryes   
#  callid_name[*]   
#  admin_vmailyes   
#  subscriber_name   
#  rcv_broadcast   
#  directory_order1   
#  accept   
#  rating_required   
#  date_created2008-02-22 08:38:01   
#  message_waiting   
#  rate   
#  directory_listingno   
#  time_zoneUS/Pacific   
#  forward_no_answeryes   
#  vmail_sort_lifo   
#  modeover-capacity   
#  subscriber_groupn/a   
#  vmail_say_time   
#  presenceinactive   
#  directory_match826   
#  language   
#  forward_busyyes   
#  callid_nmbr[*]   
#  vmail   
#  subscriber_login1007@vbox.netsapiens.com   
#  rejectyes   
#  forwardyes   
#  vmail_say_cidno   
#  email_address   
#  greeting_index
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

  tie my %hash, Tie::IxHash;
  #while ( $content =~ s/^.*?<p>\s*<b>(.+?)<\/b>\s*<(\w+)>(.+?)<\/\2><\/p>//i ) {
  while ( $content =~ s/^.*?<p>\s*<b>(.+?)<\/b>\s*(.+?)\s*<\/p>//is ) {
    ( $hash{$1} = $2 ) =~ s/^\s*<(\w+)>(.+?)<\/\1>/$2/is;
  }

  #warn $content; #probably useless

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
