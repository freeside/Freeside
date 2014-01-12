package FS::part_export::indosoft_pbx;
use base qw( FS::part_export );

use vars qw( %info );
use Tie::IxHash;
use Lingua::EN::NameParse;

tie my %options, 'Tie::IxHash',
   'host'        => { label => 'Q-Suite API hostname' },
   'gateway_key' => { label => 'API gateway key' },
;

%info = (
  'svc'      => [qw( svc_pbx svc_phone svc_acct )],
  'desc'     =>
    'Export PBX tenants and DIDs to Indosoft Q-Suite',
  'options'  => \%options,
  'no_machine' => 1,
  'notes'    => <<'END'
Export PBX tenants and DIDs to Indosoft Q-Suite.
Net::Indosoft::QSuite is required.
END
);

$insert_hack = 0;

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  my $cust_main = $svc_x->cust_svc->cust_pkg->cust_main;

  if ( $svc_x->isa('FS::svc_pbx') ) {

    my $uuid = $self->indosoft_runcommand( 'editTenant',
      'mode'          => 'create',
      'name'          => $svc_x->title || $cust_main->name,
      'shortname'     => $svc_x->svcnum, #?
      #'hostname'      => #XXX what goes here?  add to svc_pbx?
      'callerid_name' => $svc_x->title || $cust_main->name, #separate?  add to svc_pbx?
      #'callerid_number' => #XXX where tf to get this from?  svc_pbx again?
    );

    $svc_x->id( $uuid );

    # ?
    #my $unneeded_trunk_uuid = $self->indosoft_command( 'assignTrunkToTenant,
    #  'tenant_uuid' => $uuid,
    #  'trunk_id'    => $self->option('trunk_id'),
    #);

  } elsif ( $svc_x->isa('FS::svc_phone') ) {

    my $same_number = $self->indosoft_runcommand( 'editDID',
      'mode'        => 'create',
      'tenant_uuid' => $svc_x->svc_pbx->id,
      'number'      => $svc_x->phonenum,
      # 'auto_attendant_uuid' =>#XXX where to get this from? svc_phone.newfield?
    );

    #set the auto-attendant name, repeate limit, response limit, extension dialing?

    #XXX ring group?

  } elsif ( $svc_x->isa('FS::svc_acct') ) {

    my($firstname, $lastname);
    my $NameParse = new Lingua::EN::NameParse;
    if ( $NameParse->parse( $svc_x->finger ) ) {
      $firstname = $cust_main->first,
      $lastname  = $cust_main->get('last'),
    } else {
      my %name = $NameParse->components;
      $firstname = $name{given_name_1} || $name{initials_1}; #wtf NameParse, Ed?
      $lastname  = $name{surname_1};
    }

    my $uuid = $self->indosoft_command( 'editEmployee',
      'mode'        => 'create',
      'tenant_uuid' => $svc_x->svc_pbx->id,
      'username'    => $svc_x->username,
      'password'    => $svc_x->_password,
      'firstname'   => $firstname,
      'lastname'    => $firstname,
    );

  #XXX extensions (pbx_extension export?  look at how svc_phone does its device export stuff

  #XXX devices (links employee to extension (svc_acct to pbx_extension)?  how's that?  seems like they _go_ with extensions.  where to pick user?

  #XXX voicemail pin?
  #XXX extension forwarding?

  } else {
    die "guru meditation #five five five five: $svc_x is not FS::svc_pbx, FS::svc_phone or FS::svc_acct";
  }

  local($insert_hack) = 1;
  #my $error = $svc_phone->replace;
  #return $error if $error;
  $svc_x->replace;

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  return '' if $insert_hack;

  #change anything?
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  #delete conference

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
    $self->option('host'),
    $self->option('gateway_key'),
    $method,
    @_,
  );

}

sub indosoft_command {
  my( $host, $gateway_key, $method, @args ) = @_;

  eval 'use Net::Indosoft::Qsuite;';
  die $@ if $@;

  my $qsuite = new Net::Indosoft::Qsuite( 'host'        => $host,
                                          'gateway_key' => $gateway_key,
                                        );

  my $return = $qsuite->$method( @args );

  die "Indosoft error: ". $qsuite->errstr if $qsuite->errstr;

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

