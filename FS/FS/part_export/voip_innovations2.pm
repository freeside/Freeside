package FS::part_export::voip_innovations2;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch dbh);
use FS::part_export;
use FS::phone_avail;
use Data::Dumper;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'         => { label=>'VoIP Innovations API login' },
  'password'      => { label=>'VoIP Innovations API password' },
  'endpointgroup' => { label=>'VoIP Innovations endpoint group number' },
  'e911'          => { label=>'Provision E911 data',
                       type=>'checkbox',
                     },
  'no_provision_did' => { label=>'Disable DID provisioning',
                          type=>'checkbox',
                        },
  'dry_run'       => { label=>"Test mode - don't actually provision",
                       type=>'checkbox',
                     },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers / E911 to VoIP Innovations (API 2.0)',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-VoIP_Innovations">Net::VoIP_Innovations</a>
from CPAN.
END
);

sub rebless { shift; }

sub can_get_dids {
  my $self = shift;
  ! $self->option('no_provision_did');
}

sub get_dids {
  my $self = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  my %getdids = ();
  #  'orderby' => 'npa', #but it doesn't seem to work :/

  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers
    %getdids = ( 'npa'   => $opt{'areacode'},
                 'nxx'   => $opt{'exchange'},
               );
  } elsif ( $opt{'areacode'} ) { #return city (npa-nxx-XXXX)
    %getdids = ( 'npa'   => $opt{'areacode'} );
  } elsif ( $opt{'state'} ) {

    my @avail = qsearch({
      'table'    => 'phone_avail',
      'hashref'  => { 'exportnum'   => $self->exportnum,
                      'countrycode' => '1', #don't hardcode me when gp goes int'l
                      'state'       => $opt{'state'},
                    },
      'order_by' => 'ORDER BY npa',
    });

    return [ map $_->npa, @avail ] if @avail; #return cached area codes instead

    #otherwise, search for em
    %getdids = ( 'state' => $opt{'state'} );

  }

  my $dids = $self->gp_command('getDIDs', %getdids);

  if ( $dids->{'type'} eq 'Error' ) {
    my $error =  "Error running VoIP Innovations getDIDs: ".
        $dids->{'statuscode'}. ': '. $dids->{'status'}. "\n";
    warn $error;
    die $error;
  }

  my $search = $dids->{'search'};

  if ( $search->{'statuscode'} == 302200 ) {
    return [];
  } elsif ( $search->{'statuscode'} != 100 ) {

    my $error = "Error running VoIP Innovations getDIDs: ";
    if ( $search->{'statuscode'} || $search->{'status'} ) {
      $error .= $search->{'statuscode'}. ': '. $search->{'status'}. "\n";
    } else {
      $error .= Dumper($search);
    }
    warn $error;
    die $error;
  }

  my @return = ();

  #my $latas = $search->{state}{lata};
  my %latas;
  if ( grep $search->{state}{lata}{$_}, qw(name rate_center) ) {
    %latas = map $search->{state}{lata}{$_},
                 qw(name rate_center);
  } else {
    %latas = %{ $search->{state}{lata} };
  } 

  foreach my $lata ( keys %latas ) {

    #warn "LATA $lata";
    
    #my $l = $latas{$lata};
    #$l = $l->{rate_center} if exists $l->{rate_center};
    
    my $lata_dids = $self->gp_command('getDIDs', %getdids, 'lata'=>$lata);
    my $lata_search = $lata_dids->{'search'};
    unless ( $lata_search->{'statuscode'} == 100 ) {
      die "Error running VoIP Innovations getDIDs: ". $lata_search->{'status'}; #die??
    }
   
    my $l = $lata_search->{state}{lata}{'rate_center'};

    #use Data::Dumper;
    #warn Dumper($l);

    my %rate_center;
    if ( grep $l->{$_}, qw(name friendlyname) ) {
      %rate_center = map $l->{$_},
                         qw(name friendlyname);
    } else {
      %rate_center = %$l;
    } 

    foreach my $rate_center ( keys %rate_center ) {
      
      #warn "rate center $rate_center";

      my $rc = $rate_center{$rate_center}; 
      $rc = $rc->{friendlyname} if exists $rc->{friendlyname};

      my @r = ();
      if ( exists($rc->{npa}) ) {
        @r = ($rc);
      } else {
        @r = map { { 'name'=>$_, %{ $rc->{$_} } }; } keys %$rc
      }

      foreach my $r (@r) {

        my @npa = ();
        if ( exists($r->{npa}{name}) ) {
          @npa = ($r->{npa})
        } else {
          @npa = map { { 'name'=>$_, %{ $r->{npa}{$_} } } } keys %{ $r->{npa} };
        }

        foreach my $npa (@npa) {

          if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers

            #warn Dumper($npa);

            my $tn = $npa->{nxx}{tn} || $npa->{nxx}{$opt{'exchange'}}{tn};

            my @tn = ref($tn) eq 'ARRAY' ? @$tn : ($tn);
            #push @return, @tn;
            push @return,
              map {
                    if ( /^\s*(\d{3})(\d{3})(\d{4})\s*$/ ) {
                      "$1-$2-$3";
                    } else {
                      $_;
                    }
                  }
               map { ref($_) eq 'HASH' ? $_->{'content'} : $_ } #tier always 2?
               @tn;

          } elsif ( $opt{'areacode'} ) { #return city (npa-nxx-XXXX)

            if ( $npa->{nxx}{name} ) {
              @nxx = ( $npa->{nxx}{name} );
            } else {
              @nxx = keys %{ $npa->{nxx} };
            }

            push @return, map { $r->{name}. ' ('. $npa->{name}. "-$_-XXXX)"; }
                              @nxx;

          } elsif ( $opt{'state'} ) { #and not other things, then return areacode
            #my $ac = $npa->{name};
            #use Data::Dumper;
            #warn Dumper($r) unless length($ac) == 3;

            push @return, $npa->{name}
              unless grep { $_ eq $npa->{name} } @return;

          } else {
            warn "WARNING: returning nothing for get_dids without known options"; #?
          }

        } #foreach my $npa

      } #foreach my $r

    } #foreach my $rate_center

  } #foreach my $lata

  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers
    @return = sort { $a cmp $b } @return; #string comparison actually dwiw
  } elsif ( $opt{'areacode'} ) { #return city (npa-nxx-XXXX)
    @return = sort { lc($a) cmp lc($b) } @return;
  } elsif ( $opt{'state'} ) { #and not other things, then return areacode

    #populate cache

    local $SIG{HUP} = 'IGNORE';
    local $SIG{INT} = 'IGNORE';
    local $SIG{QUIT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';
    local $SIG{TSTP} = 'IGNORE';
    local $SIG{PIPE} = 'IGNORE';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my $errmsg = 'WARNING: error populating phone availability cache: ';
    my $error = '';
    foreach my $return (@return) {
      my $phone_avail = new FS::phone_avail {
        'exportnum'   => $self->exportnum,
        'countrycode' => '1', #don't hardcode me when gp goes int'l
        'state'       => $opt{'state'},
        'npa'         => $return,
      };
      $error = $phone_avail->insert();
      if ( $error ) {
        warn $errmsg.$error;
        last;
      }
    }

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
    } else {
      $dbh->commit or warn $errmsg.$dbh->errstr if $oldAutoCommit;
    }

    #end populate cache

    #@return = sort { (split(' ', $a))[0] <=> (split(' ', $b))[0] } @return;
    @return = sort { $a <=> $b } @return;
  } else {
    warn "WARNING: returning nothing for get_dids without known options"; #?
  }

  \@return;

}

sub gp_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::VoIP_Innovations 2.00;";
  if ( $@ ) {
    warn $@;
    die $@;
  }

  my $gp = Net::VoIP_Innovations->new(
    'login'    => $self->option('login'),
    'password' => $self->option('password'),
    #'debug'    => $debug,
  );

  $gp->$command(@args);
}


sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  unless ( $self->option('no_provision_did') ) {

    ###
    # reserveDID
    ###

    my $r = $self->gp_command('reserveDID',
      'did'           => $svc_phone->phonenum,
      'minutes'       => 1,
      'endpointgroup' => $self->option('endpointgroup'),
    );

    my $rdid = $r->{did};

    if ( $rdid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations reserveDID: ".
             $rdid->{'statuscode'}. ': '. $rdid->{'status'};
    }

    ###
    # assignDID
    ###

    my $a = $self->gp_command('assignDID',
      'did'           => $svc_phone->phonenum,
      'endpointgroup' => $self->option('endpointgroup'),
      #'rewrite'
      #'cnam'
    );

    my $adid = $a->{did};

    if ( $adid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations assignDID: ".
             $adid->{'statuscode'}. ': '. $adid->{'status'};
    }

  }

  ###
  # 911Insert
  ###

  if ( $self->option('e911') ) {

    my %location_hash = $svc_phone->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $e = $self->gp_command('911Insert',
      'did'        => $svc_phone->phonenum,
      'Address1'   => $location_hash{address1},
      'Address2'   => $location_hash{address2},
      'City'       => $location_hash{city},
      'State'      => $location_hash{state},
      'ZipCode'    => $zip,
      'PlusFour'   => $plus4,
      'CallerName' =>
        $svc_phone->phone_name
          || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
    );

    my $edid = $e->{did};

    if ( $edid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations 911Insert: ".
             $edid->{'statuscode'}. ': '. $edid->{'status'};
    }

  }

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  #hmm, anything to change besides E911 data?

  ###
  # 911Update
  ###

  if ( $self->option('e911') ) {

    my %location_hash = $svc_phone->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $e = $self->gp_command('911Update',
      'did'        => $svc_phone->phonenum,
      'Address1'   => $location_hash{address1},
      'Address2'   => $location_hash{address2},
      'City'       => $location_hash{city},
      'State'      => $location_hash{state},
      'ZipCode'    => $zip,
      'PlusFour'   => $plus4,
      'CallerName' =>
        $svc_phone->phone_name
          || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
    );

    my $edid = $e->{did};

    if ( $edid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations 911Update: ".
             $edid->{'statuscode'}. ': '. $edid->{'status'};
    }

  }

  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #probably okay to queue the deletion...?
  #but hell, let's do it inline anyway, who wants phone numbers hanging around

  unless ( $self->option('no_provision_did') ) {

    my $r = $self->gp_command('releaseDID',
      'did'           => $svc_phone->phonenum,
    );

    my $rdid = $r->{did};

    if ( $rdid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations releaseDID: ".
             $rdid->{'statuscode'}. ': '. $rdid->{'status'};
    }

  }

  #delete e911 information?  assuming release clears all that
  #if ( $self->option('e911') ) {
  #  # but need to handle the no_provision_did case
  #}

  '';
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

#hmm, might forgo queueing entirely for most things, data is too much of a pita
#sub globalpops_voip_queue {
#  my( $self, $svcnum, $method ) = (shift, shift, shift);
#  my $queue = new FS::queue {
#    'svcnum' => $svcnum,
#    'job'    => 'FS::part_export::globalpops_voip::globalpops_voip_command',
#  };
#  $queue->insert(
#    $self->option('login'),
#    $self->option('password'),
#    $method,
#    @_,
#  );
#}
#
#sub globalpops_voip_command {
#  my($login, $password, $method, @args) = @_;
#
#  eval "use Net::GlobalPOPs::MediaServicesAPI 0.03;";
#  die $@ if $@;
#
#  my $gp = new Net::GlobalPOPs::MediaServicesAPI
#                 'login'    => $login,
#                 'password' => $password,
#                 #'debug'    => 1,
#               ;
#
#  my $return = $gp->$method( @args );
#
#  #$return->{'status'} 
#  #$return->{'statuscode'} 
#
#  die $return->{'status'} if $return->{'statuscode'};
#
#}

1;

