package FS::part_export::soma;

use vars qw(@ISA %info %options $DEBUG);
use Tie::IxHash;
use FS::Record qw(fields dbh);
use FS::part_export;

@ISA = qw(FS::part_export);
$DEBUG = 1;

tie %options, 'Tie::IxHash',
  'url'         => { label => 'Soma OSS-API url', default=>'https://localhost:8088/ossapi/services' },
  'data_app_id' => { label => 'SOMA Data Application Id', default => '' },
;

my $notes = <<'EOT';
Real-time export of <b>svc_external</b> and <b>svc_broadband</b> record data
to SOMA Networks <a href="http://www.somanetworks.com">platform</a> via the
OSS-API.<br><br>

Freeside will attempt to create/delete a cpe for the ESN provided in
svc_external.  If a data application id is provided then freeside will
use the values provided in svc_broadband to manage the attributes and 
features of that cpe.

EOT

%info = (
  'svc'      => [ qw ( svc_broadband svc_external ) ],
  'desc'     => 'Real-time export to SOMA platform',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => $notes,
);

sub _export_insert {
  my( $self, $svc ) = ( shift, shift );

  warn "_export_insert called for service ". $svc->svcnum
    if $DEBUG;

  my %args = ( url => $self->option('url'), method => '_queueable_insert' );

  $args{esn} = $self->esn($svc) or return 'No ESN found!';

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  $args{svcdb} = $svcdb;
  if ( $svcdb eq 'svc_external' ) {
    #do nothing
  } elsif ( $svcdb eq 'svc_broadband' ){
    $args{data_app_id} = $self->option('data_app_id')
  } else {
    return "Don't know how to provision $svcdb";
  }

  warn "dispatching statuschange" if $DEBUG;

  eval { statuschange(%args) };
  return $@ if $@;

  '';
}

sub _export_delete {
  my( $self, $svc ) = ( shift, shift );

  my %args = ( url => $self->option('url'), method => '_queueable_delete' );

  $args{esn} = $self->esn($svc) or return 'No ESN found!';

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  $args{svcdb} = $svcdb;
  if ( $svcdb eq 'svc_external' ) {
    #do nothing
  } elsif ( $svcdb eq 'svc_broadband' ){
    $args{data_app_id} = $self->option('data_app_id')
  } else {
    return "Don't know how to provision $svcdb";
  }

  eval { statuschange(%args) };
  return $@ if $@;

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  my %args = ( url => $self->option('url'), method => '_queueable_replace' );

  $args{esn}     = $self->esn($old) or return 'No old ESN found!';
  $args{new_esn} = $self->esn($new) or return 'No new ESN found!';

  my $svcdb = $old->cust_svc->part_svc->svcdb;
  $args{svcdb} = $svcdb;
  if ( $svcdb eq 'svc_external' ) {
    #do nothing
  } elsif ( $svcdb eq 'svc_broadband' ){
    $args{data_app_id} = $self->option('data_app_id')
  } else {
    return "Don't know how to provision $svcdb";
  }

  eval { statuschange(%args) };
  return $@ if $@;

  '';
}

sub _export_suspend {
  my( $self, $svc ) = ( shift, shift );

  $self->queue_statuschange('_queueable_suspend', $svc);
}

sub _export_unsuspend {
  my( $self, $svc ) = ( shift, shift );

  $self->queue_statuschange('_queueable_unsuspend', $svc);
}

sub queue_statuschange {
  my( $self, $method, $svc ) = @_;

  my %args = ( url => $self->option('url'), method => $method );

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  $args{svcdb} = $svcdb;
  if ( $svcdb eq 'svc_external' ) {
    #do absolutely nothing
    return '';
  } elsif ( $svcdb eq 'svc_broadband' ){
    $args{data_app_id} = $self->option('data_app_id')
  } else {
    return "Don't know how to provision $svcdb";
  }

  $args{esn} = $self->esn($svc);

  my $queue = new FS::queue {
    'svcnum' => $svc->svcnum,
    'job'    => 'FS::part_export::soma::$method',
  };
  my $error = $queue->insert( $self->option('url'), %args );

  return $error if $error;

  '';

}

sub statuschange {  # subroutine
  my( %options ) = @_;

  warn "statuschange called with options ". 
       join (', ', map { "$_ => $options{$_}" } keys(%options))
    if $DEBUG;

  my $method = $options{method};

  eval "use Net::Soma 0.01 qw(ApplicationDef ApplicationInstance
                              AttributeDef AttributeInstance);";
  die $@ if $@;

  my %soma_objects = ();
  foreach my $service ( qw ( CPECollection CPEAccess AppCatalog Applications ) )
  {
    $soma_objects{$service} = new Net::Soma ( namespace => $service."Service",
                                              url       => $options{'url'},
                                              die_on_fault => 1,
                                            );
  }
  
  my $cpeid = eval {$soma_objects{CPECollection}->getCPEByESN( $options{esn} )};
  warn "failed to find CPE with ESN $options{esn}"
    if ($DEBUG && !$cpeid);

  if ( $method eq '_queueable_insert' && $options{svcdb} eq 'svc_external' ) {
    if ( !$cpeid ) {
      # only type 1 is used at this time
      $cpeid = $soma_objects{CPECollection}->createCPE( $options{esn}, 1 );
    } else {
      $soma_objects{CPECollection}->releaseCPE( $cpeid );
      die "Soma element for $options{esn} already exists";
    }
  }

  die "Can't find soma element for $options{esn}"
    unless $cpeid;

  warn "dispatching $method from statuschange" if $DEBUG;
  &{$method}( \%soma_objects, $cpeid, %options );

}

sub _queueable_insert {
  my( $soma_objects, $cpeid, %options ) = @_;

  warn "_queueable_insert called for $cpeid with options ". 
       join (', ', map { "$_ => $options{$_}" } keys(%options))
    if $DEBUG;

  my $appid = $options{data_app_id};
  if ($appid) {
    my $application =
      $soma_objects->{AppCatalog}
                   ->getDefaultApplicationInstance($appid, $cpeid);

    my $attribute =
      $soma_objects->{AppCatalog}
                   ->getDefaultApplicationAttributeInstance(2, 1, $cpeid);
    $attribute->value('G');

    my $i = 0;
    foreach my $instance (@{$application->attributes}) {
      unless ($instance->definitionId == $attribute->definitionId) {
        $i++; next;
      }
      $application->attributes->[$i] = $attribute;
      last;
    }

    $soma_objects->{Applications}->subscribeApp( $cpeid, $application );
  }

  $soma_objects->{CPECollection}->releaseCPE( $cpeid );

  '';
}

sub _queueable_delete {
  my( $soma_objects, $cpeid, %options ) = @_;

  my $appid = $options{data_app_id};
  my $norelease;

  if ($appid) {
    my $applications =
      $soma_objects->{Applications}->getSubscribedApplications( $cpeid );

    my $instance_id;
    foreach $application (@$applications) {
      next unless $application->definitionId == $appid;
      $instance_id = $application->instanceId;
    }

    $soma_objects->{Applications}->unsubscribeApp( $cpeid, $instance_id );

  } else {

    $soma_objects->{CPECollection}->deleteCPE($cpeid);
    $norelease = 1;

  }

  $soma_objects->{CPECollection}->releaseCPE( $cpeid ) unless $norelease;

  '';
}

sub _queueable_replace {
  my( $soma_objects, $cpeid, %options ) = @_;

  my $appid = $options{data_app_id} || '';

  if (exists($options{data_app_id})) {
    my $applications =
      $soma_objects->{Applications}->getSubscribedApplications( $cpeid );

    my $instance_id;
    foreach $application (@$applications) {
      next unless $application->internalName eq 'dataApplication';
      if ($application->definitionId != $options{data_app_id}) {
        $instance_id = $application->instanceId;
        $soma_objects->{Applications}->unsubscribeApp( $cpeid, $instance_id );
      }
    }

    if ($appid && !$instance_id ) {
      my $application =
        $soma_objects->{AppCatalog}
                     ->getDefaultApplicationInstance($appid, $cpeid);

      $soma_objects->{Applications}->subscribeApp( $cpeid, $application );
    }

  } else {

    $soma_objects->{CPEAccess}->switchCPE($cpeid, $options{new_esn})
      unless( $options{new_esn} eq $options{esn});

  }

  $soma_objects->{CPECollection}->releaseCPE( $cpeid );

  '';
}

sub _queueable_suspend {
  my( $soma_objects, $cpeid, %options ) = @_;

  my $appid = $options{data_app_id};

  if ($appid) {
    my $applications =
      $soma_objects->{Applications}->getSubscribedApplications( $cpeid );

    my $instance_id;
    foreach $application (@$applications) {
      next unless $application->definitionId == $appid;

      $instance_id = $application->instanceId;
      $app_def = $app_catalog->getApplicationDef($appid, $cpeid);
      @attr_def = grep { $_->internalName eq 'status' } @{$app_def->attributes};

      foreach my $attribute ( @{$application->attributes} ) {
        next unless $attibute->definitionId == $attr_def[0]->definitionId;
        $attribute->{value} = 'S';  

        $soma_objects->{Applications}->setAppAttribute( $cpeid,
                                                        $instance_id,
                                                        $attribute
                                                      );
      }
      
    }

  } else {

    #do nothing

  }

  $soma_objects->{CPECollection}->releaseCPE( $cpeid );

  '';
}

sub _queueable_unsuspend {
  my( $soma_objects, $cpeid, %options ) = @_;

  my $appid = $options{data_app_id};

  if ($appid) {
    my $applications =
      $soma_objects->{Applications}->getSubscribedApplications( $cpeid );

    my $instance_id;
    foreach $application (@$applications) {
      next unless $application->definitionId == $appid;

      $instance_id = $application->instanceId;
      $app_def = $app_catalog->getApplicationDef($appid, $cpeid);
      @attr_def = grep { $_->internalName eq 'status' } @{$app_def->attributes};

      foreach my $attribute ( @{$applicate->attributes} ) {
        next unless $attibute->definitionId == $attr_def[0]->definitionId;
        $attribute->{value} = 'E';  

        $soma_objects->{Applications}->setAppAttribute( $cpeid,
                                                        $instance_id,
                                                        $attribute
                                                      );
      }
      
    }

  } else {

    #do nothing

  }

  $soma_objects->{CPECollection}->releaseCPE( $cpeid );

  '';
}

sub esn {
  my ( $self, $svc ) = @_;
  my $svcdb = $svc->cust_svc->part_svc->svcdb;

  return sprintf( '%016d', $svc->id ) if $svcdb eq 'svc_external';
  
  my $cust_pkg = $svc->cust_svc->cust_pkg;
  return '' unless $cust_pkg;

  my @cust_svc = grep { $_->part_svc->svcdb eq 'svc_external' &&
                        scalar( $_->part_svc->part_export('soma') )
                      }
                 $cust_pkg->cust_svc;
  return '' unless scalar(@cust_svc);
  warn "part_export::soma found multiple ESNs for cust_svc ". $svc->svcnum
    if scalar( @cust_svc ) > 1;

  sprintf( '%016d', $cust_svc[0]->svc_x->id );
}


1;
