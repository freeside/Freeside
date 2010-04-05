package FS::part_export::indosoft;

use vars qw(@ISA %info $insert_hack);
use Tie::IxHash;
use Date::Format;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
   'url'        => { label => 'Voicebridge API URL' },
   'account_id' => { label => 'Voicebridge Account ID' },
;

%info = (
  'svc'      => 'svc_phone', #svc_bridge?  svc_confbridge?
  'desc'     =>
    'Export conferences to the Indosoft Conference Bridge',
  'options'  => \%options,
  'notes'    => <<'END'
Export conferences to the Indosoft conference bridge.
Net::Indosoft::Voicebridge is required.
END
);

$insert_hack = 0;

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_phone) = (shift, shift);

  my $cust_main = $svc_phone->cust_svc->cust_pkg->cust_main;

  my $address = $cust_main->address1;
  $address .= ' '.$cust_main->address2 if $cust_main->address2;

  my $phone = $cust_main->daytime || $cust_main->night;

  my @email = $cust_main->invoicing_list_emailonly;

  #svc_phone->location_hash stuff?  well that was for e911.. this shouldn't
  # even be svc_phone

  #add client
  my $client_return = eval {
    indosoft_runcommand( 'addClient',
      'account_id' => $self->option('account_id'),

      'client_contact_name'     => $cust_main->name, #or just first last?
      'client_contact_password' => $svc_phone->sip_password, # ?

      'client_contact_addr'     => $address,
      'client_contact_city'     => $cust_main->city,
      'client_contact_state'    => $cust_main->state,
      'client_contact_country'  => $cust_main->country,
      'client_contact_zip'      => $cust_main->zip,

      'client_contact_phone'    => $phone,
      'client_contact_fax'      => $cust_main->fax,
      'client_contact_email'    => $email[0],
    );
  };
  return $@ if $@;

  my $client_id = $client_return->{client_id};

  #add conference
  my $conf_return = eval {
    indosoft_runcommand( 'addConference',
      'client_id'          => $client_id,
      'conference_name'    => $cust_main->name,
      'conference_desc'    => $svc_phone->svcnum. ' for '. $cust_main->name,
      'start_time'         => time2str('%Y-%d-$m %T', time), #now, right??  '2010-20-04 16:20:00',
      #'moderated_flag'     => 0,
      #'entry_ann_flag'     => 0
      #'record_flag'        => 0
      #'moh_flag'           => 0
      #'talk_detect_flag'   => 0
      #'play_user_cnt_flag' => 0
      #'wait_for_admin'     => 0
      #'stop_on_admin_exit' => 0
      #'second_pin'         => 0
      #'secondary_pin'      => 0,
      #'allow_sub-conf'     => 0,
      #'duration'           => 0,
      #'conference_type' => 'reservation', #'reservationless',
    );
  };
  return $@ if $@;

  my $conference_id = $conf_return->{conference_id};

  #put conference_id in svc_phone.phonenum (and client_id in... phone_name???)
  local($insert_hack) = 1;
  $svc_phone->phonenum($conference_id);
  $svc_phone->phone_name($client_id);
  #my $error = $svc_phone->replace;
  #return $error if $error;
  $svc_phone->replace;

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change phone number as conference_id with indosoft"
    if $old->phonenum ne $new->phonenum && ! $insert_hack;
  return '';

  #change anything?
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  #delete conference
  my $conf_return = eval {
    indosoft_runcommand( 'deleteConference',
      'conference_id' => $svc_phone->phonenum,
    );
  };
  return $@ if $@;

  #delete client
  my $client_return = eval {
    indosoft_runcommand( 'deleteClient',
      'client_id' => $svc_phone->phone_name,
    )
  };
  return $@ if $@;

  '';

}

# #these three are optional
# # fallback for svc_acct will change and restore password
# sub _export_suspend {
#   my( $self, $svc_phone ) = (shift, shift);
#   $err_or_queue = $self->indosoft_queue( $svc_phone->svcnum,
#     'suspend', $svc_phone->username );
#   ref($err_or_queue) ? '' : $err_or_queue;
# }
# 
# sub _export_unsuspend {
#   my( $self, $svc_phone ) = (shift, shift);
#   $err_or_queue = $self->indosoft_queue( $svc_phone->svcnum,
#     'unsuspend', $svc_phone->username );
#   ref($err_or_queue) ? '' : $err_or_queue;
# }
# 
# sub export_links {
#   my($self, $svc_phone, $arrayref) = (shift, shift, shift);
#   #push @$arrayref, qq!<A HREF="http://example.com/~!. $svc_phone->username.
#   #                 qq!">!. $svc_phone->username. qq!</A>!;
#   '';
# }

###

sub indosoft_runcommand {
  my( $self, $method ) = (shift, shift);

  indosoft_command(
    $self->option('url'),
    $method,
    @_,
  );

}

sub indosoft_command {
  my( $url, $method, @args ) = @_;

  eval 'use Net::Indosoft::Voicebridge;';
  die $@ if $@;

  my $vb = new Net::Indosoft::Voicebridge( 'url' => $url );

  my $return = $vb->$method( @args );

  die "Indosoft error: ". $return->{'error'} if $return->{'error'};

  $return;

}


# #a good idea to queue anything that could fail or take any time
# sub indosoft_queue {
#   my( $self, $svcnum, $method ) = (shift, shift, shift);
#   my $queue = new FS::queue {
#     'svcnum' => $svcnum,
#     'job'    => "FS::part_export::indosoft::indosoft_$method",
#   };
#   $queue->insert( @_ ) or $queue;
# }
# 
# sub indosoft_insert { #subroutine, not method
#   my( $username, $password ) = @_;
#   #do things with $username and $password
# }
# 
# sub indosoft_replace { #subroutine, not method
# }
# 
# sub indosoft_delete { #subroutine, not method
#   my( $username ) = @_;
#   #do things with $username
# }
# 
# sub indosoft_suspend { #subroutine, not method
# }
# 
# sub indosoft_unsuspend { #subroutine, not method
# }


1;
