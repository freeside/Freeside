package FS::svc_broadband;
use base qw(
  FS::svc_Radius_Mixin
  FS::svc_Tower_Mixin
  FS::svc_Torrus_Mixin
  FS::svc_IP_Mixin 
  FS::MAC_Mixin
  FS::svc_Common
);

use strict;
use vars qw($conf);

{ no warnings 'redefine'; use NetAddr::IP; }
use FS::Record qw( qsearchs qsearch dbh );
use FS::cust_svc;
use FS::addr_block;
use FS::part_svc_router;
use FS::tower_sector;

$FS::UID::callback{'FS::svc_broadband'} = sub { 
  $conf = new FS::Conf;
};

=head1 NAME

FS::svc_broadband - Object methods for svc_broadband records

=head1 SYNOPSIS

  use FS::svc_broadband;

  $record = new FS::svc_broadband \%hash;
  $record = new FS::svc_broadband { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_broadband object represents a 'broadband' Internet connection, such
as a DSL, cable modem, or fixed wireless link.  These services are assumed to
have the following properties:

FS::svc_broadband inherits from FS::svc_Common.  The following fields are
currently supported:

=over 4

=item svcnum - primary key

=item blocknum - see FS::addr_block

=item
speed_up - maximum upload speed, in bits per second.  If set to zero, upload
speed will be unlimited.  Exports that do traffic shaping should handle this
correctly, and not blindly set the upload speed to zero and kill the customer's
connection.

=item
speed_down - maximum download speed, as above

=item ip_addr - the customer's IP address.  If the customer needs more than one
IP address, set this to the address of the customer's router.  As a result, the
customer's router will have the same address for both its internal and external
interfaces thus saving address space.  This has been found to work on most NAT
routers available.

=item plan_id

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_broadband.  To add the record to the database, see
"insert".

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table_info {
  {
    'name' => 'Wireless broadband',
    'name_plural' => 'Wireless broadband services',
    'longname_plural' => 'Fixed wireless broadband services',
    'display_weight' => 50,
    'cancel_weight'  => 70,
    'ip_field' => 'ip_addr',
    'fields' => {
      'svcnum'      => 'Service',
      'description' => 'Descriptive label',
      'speed_down'  => 'Download speed (Kbps)',
      'speed_up'    => 'Upload speed (Kbps)',
      'ip_addr'     => 'IP address',
      'blocknum'    => 
      { 'label' => 'Address block',
                         'type'  => 'select',
                         'select_table' => 'addr_block',
                          'select_key'   => 'blocknum',
                         'select_label' => 'cidr',
                         'disable_inventory' => 1,
                       },
     'plan_id' => 'Service Plan Id',
     'performance_profile' => 'Peformance Profile',
     'authkey'      => 'Authentication key',
     'mac_addr'     => 'MAC address',
     'latitude'     => 'Latitude',
     'longitude'    => 'Longitude',
     'altitude'     => 'Altitude',
     'vlan_profile' => 'VLAN profile',
     'sectornum'    => 'Tower/sector',
     'routernum'    => 'Router/block',
     'usergroup'    => { 
                         label => 'RADIUS groups',
                         type  => 'select-radius_group.html',
                         #select_table => 'radius_group',
                         #select_key   => 'groupnum',
                         #select_label => 'groupname',
                         disable_inventory => 1,
                         multiple => 1,
                       },
      'radio_serialnum' => 'Radio Serial Number',
      'radio_location'  => 'Radio Location',
      'poe_location'    => 'POE Location',
      'rssi'            => 'RSSI',
      'suid'            => 'SUID',
      'shared_svcnum'   => { label             => 'Shared Service',
                             type              => 'search-svc_broadband',
                             disable_inventory => 1,
                           },
      'serviceid' => 'Torrus serviceid', #but is should be hidden
    },
  };
}

sub table { 'svc_broadband'; }

sub table_dupcheck_fields { ( 'ip_addr', 'mac_addr' ); }

=item search HASHREF

Class method which returns a qsearch hash expression to search for parameters
specified in HASHREF.

Parameters:

=over 4

=item unlinked - set to search for all unlinked services.  Overrides all other options.

=item agentnum

=item custnum

=item svcpart

=item ip_addr

=item pkgpart - arrayref

=item routernum - arrayref

=item sectornum - arrayref

=item towernum - arrayref

=item order_by

=back

=cut

sub _search_svc {
  my( $class, $params, $from, $where ) = @_;

  #routernum, can be arrayref
  for my $routernum ( $params->{'routernum'} ) {
    # this no longer uses addr_block
    if ( ref $routernum and grep { $_ } @$routernum ) {
      my $in = join(',', map { /^(\d+)$/ ? $1 : () } @$routernum );
      my @orwhere = ();
      push @orwhere, "svc_broadband.routernum IN ($in)" if $in;
      push @orwhere, "svc_broadband.routernum IS NULL" 
        if grep /^none$/, @$routernum;
      push @$where, '( '.join(' OR ', @orwhere).' )';
    }
    elsif ( $routernum =~ /^(\d+)$/ ) {
      push @$where, "svc_broadband.routernum = $1";
    }
    elsif ( $routernum eq 'none' ) {
      push @$where, "svc_broadband.routernum IS NULL";
    }
  }

  #this should probably move to svc_Tower_Mixin, or maybe we never should have
  # done svc_acct # towers (or, as mark thought, never should have done
  # svc_broadband)

  #sector and tower, as above
  my @where_sector = $class->tower_sector_sql($params);
  if ( @where_sector ) {
    push @$where, @where_sector;
    push @$from, 'LEFT JOIN tower_sector USING ( sectornum )';
  }
 
  #ip_addr
  if ( $params->{'ip_addr'} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
    push @$where, "ip_addr = '$1'";
  }

}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

sub search_sql {
  my( $class, $string ) = @_;
  if ( $string =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
    $class->search_sql_field('ip_addr', $string );
  } elsif ( $string =~ /^([A-F0-9]{12})$/i ) {
    $class->search_sql_field('mac_addr', uc($string));
  } elsif ( $string =~ /^(([A-F0-9]{2}:){5}([A-F0-9]{2}))$/i ) {
    $string =~ s/://g;
    $class->search_sql_field('mac_addr', uc($string) );
  } elsif ( $string =~ /^(\d+)$/ ) {
    my $table = $class->table;
    "$table.svcnum = $1";
  } else {
    '1 = 0'; #false
  }
}

=item smart_search STRING

=cut

sub smart_search {
  my( $class, $string ) = @_;
  qsearch({
    'table'     => $class->table, #'svc_broadband',
    'hashref'   => {},
    'extra_sql' => 'WHERE '. $class->search_sql($string),
  });
}

=item label

Returns the IP address, MAC address and description.

=cut

sub label {
  my $self = shift;
  my $label = 'IP:'. ($self->ip_addr || 'Unknown');
  $label .= ', MAC:'. $self->mac_addr
    if $self->mac_addr;
  $label .= ' ('. $self->description. ')'
    if $self->description;
  return $label;
}

=item insert [ , OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see FS::cust_svc) should be 
defined.  An FS::cust_svc record will be created and inserted.

Currently available options are: I<depend_jobnum>

If I<depend_jobnum> is set (to a scalar jobnum or an array reference of
jobnums), all provisioning jobs will have a dependancy on the supplied
jobnum(s) (they will not run until the specific job(s) complete(s)).

=cut

# Standard FS::svc_Common::insert

=item delete

Delete this record from the database.

=cut

# Standard FS::svc_Common::delete

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

# Standard FS::svc_Common::replace

=item suspend

Called by the suspend method of FS::cust_pkg (see FS::cust_pkg).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see FS::cust_pkg).

=item cancel

Called by the cancel method of FS::cust_pkg (see FS::cust_pkg).

=item check

Checks all fields to make sure this is a valid broadband service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $x = $self->setfixed;

  return $x unless ref($x);

  # remove delimiters
  my $mac_addr = uc($self->get('mac_addr'));
  $mac_addr =~ s/[\W_]//g;
  $self->set('mac_addr', $mac_addr);

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('blocknum')
    || $self->ut_foreign_keyn('routernum', 'router', 'routernum')
    || $self->ut_foreign_keyn('sectornum', 'tower_sector', 'sectornum')
    || $self->ut_textn('description')
    || $self->ut_numbern('speed_up')
    || $self->ut_numbern('speed_down')
    || $self->ut_ipn('ip_addr')
    || $self->ut_hexn('mac_addr')
    || $self->ut_hexn('auth_key')
    || $self->ut_coordn('latitude')
    || $self->ut_coordn('longitude')
    || $self->ut_sfloatn('altitude')
    || $self->ut_textn('vlan_profile')
    || $self->ut_textn('plan_id')
    || $self->ut_alphan('radio_serialnum')
    || $self->ut_textn('radio_location')
    || $self->ut_textn('poe_location')
    || $self->ut_snumbern('rssi')
    || $self->ut_numbern('suid')
    || $self->ut_foreign_keyn('shared_svcnum', 'svc_broadband', 'svcnum')
    || $self->ut_textn('serviceid') #too lenient?
  ;
  return $error if $error;

  if(($self->speed_up || 0) < 0) { return 'speed_up must be positive'; }
  if(($self->speed_down || 0) < 0) { return 'speed_down must be positive'; }

  my $cust_svc = $self->svcnum
                 ? qsearchs('cust_svc', { 'svcnum' => $self->svcnum } )
                 : '';
  my $cust_pkg;
  my $svcpart;
  if ($cust_svc) {
    $cust_pkg = $cust_svc->cust_pkg;
    $svcpart = $cust_svc->svcpart;
  }else{
    $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $self->pkgnum } );
    return "Invalid pkgnum" unless $cust_pkg;
    $svcpart = $self->svcpart;
  }
  my $agentnum = $cust_pkg->cust_main->agentnum if $cust_pkg;

  # assign IP address / router / block
  $error = $self->svc_ip_check;
  return $error if $error;
  if ( !$self->ip_addr 
       and !$conf->exists('svc_broadband-allow_null_ip_addr') ) {
    return 'IP address is required';
  }

  if ( $cust_pkg && ! $self->latitude && ! $self->longitude ) {
    my $l = $cust_pkg->cust_location_or_main;
    if ( $l->ship_latitude && $l->ship_longitude ) {
      $self->latitude(  $l->ship_latitude  );
      $self->longitude( $l->ship_longitude );
    } elsif ( $l->latitude && $l->longitude ) {
      $self->latitude(  $l->latitude  );
      $self->longitude( $l->longitude );
    }
  }

  $self->SUPER::check;
}

sub _check_duplicate {
  my $self = shift;
  # Not a reliable check because the table isn't locked, but 
  # that's why we have a unique index.  This is just to give a
  # friendlier error message.
  my @dup;
  @dup = $self->find_duplicates('global', 'mac_addr');
  if ( @dup ) {
    return "MAC address in use (svcnum ".$dup[0]->svcnum.")";
  }

  '';
}

#class method
sub _upgrade_data {
  my $class = shift;

  local($FS::svc_Common::noexport_hack) = 1;

  # fix wrong-case MAC addresses
  my $dbh = dbh;
  $dbh->do('UPDATE svc_broadband SET mac_addr = UPPER(mac_addr);')
    or die $dbh->errstr;

  # set routernum to addr_block.routernum
  foreach my $self (qsearch('svc_broadband', {
      blocknum => {op => '!=', value => ''},
      routernum => ''
    })) {
    my $addr_block = $self->addr_block;
    if ( !$addr_block ) {
      # super paranoid mode
      warn "WARNING: svcnum ".$self->svcnum." is assigned to addr_block ".$self->blocknum.", which does not exist; skipped.\n";
      next;
    }
    my $ip_addr = $self->ip_addr;
    my $routernum = $addr_block->routernum;
    if ( $routernum ) {
      $self->set(routernum => $routernum);
      my $error = $self->check;
      # sanity check: don't allow this to change IP address or block
      # (other than setting blocknum to null for a non-auto-assigned router)
      if ( $self->ip_addr ne $ip_addr 
        or ($self->blocknum and $self->blocknum != $addr_block->blocknum)) {
        warn "WARNING: Upgrading service ".$self->svcnum." would change its block/address; skipped.\n";
        next;
      }

      $error ||= $self->replace;
      warn "WARNING: error assigning routernum $routernum to service ".$self->svcnum.
          ":\n$error; skipped\n"
        if $error;
    }
    else {
      warn "svcnum ".$self->svcnum.
        ": no routernum in address block ".$addr_block->cidr.", skipped\n";
    }
  }

  # assign blocknums to services that should have them
  my @all_blocks = qsearch('addr_block', { });
  SVC: foreach my $self ( 
    qsearch({
        'select' => 'svc_broadband.*',
        'table' => 'svc_broadband',
        'addl_from' => 'JOIN router USING (routernum)',
        'hashref' => {},
        'extra_sql' => 'WHERE svc_broadband.blocknum IS NULL '.
                       'AND router.manual_addr IS NULL',
    }) 
  ) {
   
    next SVC if $self->ip_addr eq '';
    my $NetAddr = $self->NetAddr;
    # inefficient, but should only need to run once
    foreach my $block (@all_blocks) {
      if ($block->NetAddr->contains($NetAddr)) {
        $self->set(blocknum => $block->blocknum);
        my $error = $self->replace;
        warn "WARNING: error assigning blocknum ".$block->blocknum.
        " to service ".$self->svcnum."\n$error; skipped\n"
          if $error;
        next SVC;
      }
    }
    warn "WARNING: no block found containing ".$NetAddr->addr." for service ".
      $self->svcnum;
    #next SVC;
  }

  '';
}

=back

=head1 BUGS

The business with sb_field has been 'fixed', in a manner of speaking.

allowed_routers isn't agent virtualized because part_svc isn't agent
virtualized

Having both routernum and blocknum as foreign keys is somewhat dubious.

=head1 SEE ALSO

FS::svc_Common, FS::Record, FS::addr_block,
FS::part_svc, schema.html from the base documentation.

=cut

1;

