package FS::svc_broadband;

use strict;
use vars qw(@ISA $conf);

use base qw(FS::svc_Radius_Mixin FS::svc_Tower_Mixin FS::svc_Common);
{ no warnings 'redefine'; use NetAddr::IP; }
use FS::Record qw( qsearchs qsearch dbh );
use FS::svc_Common;
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
    'name' => 'Broadband',
    'name_plural' => 'Broadband services',
    'longname_plural' => 'Fixed (username-less) broadband services',
    'display_weight' => 50,
    'cancel_weight'  => 70,
    'ip_field' => 'ip_addr',
    'fields' => {
      'svcnum'      => 'Service',
      'description' => 'Descriptive label for this particular device',
      'speed_down'  => 'Maximum download speed for this service in Kbps.  0 denotes unlimited.',
      'speed_up'    => 'Maximum upload speed for this service in Kbps.  0 denotes unlimited.',
      #'ip_addr'     => 'IP address.  Leave blank for automatic assignment.',
      #'blocknum'    => 
      #{ 'label' => 'Address block',
      #                   'type'  => 'select',
      #                   'select_table' => 'addr_block',
      #                    'select_key'   => 'blocknum',
      #                   'select_label' => 'cidr',
      #                   'disable_inventory' => 1,
      #                 },
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
    },
  };
}

sub table { 'svc_broadband'; }

sub table_dupcheck_fields { ( 'mac_addr' ); }

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

sub search {
  my ($class, $params) = @_;
  my @where = ();
  my @from = (
    'LEFT JOIN cust_svc  USING ( svcnum  )',
    'LEFT JOIN part_svc  USING ( svcpart )',
    'LEFT JOIN cust_pkg  USING ( pkgnum  )',
    'LEFT JOIN cust_main USING ( custnum )',
  );

  # based on FS::svc_acct::search, probably the most mature of the bunch
  #unlinked
  push @where, 'pkgnum IS NULL' if $params->{'unlinked'};
  
  #agentnum
  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where, "cust_main.agentnum = $1";
  }
  push @where, $FS::CurrentUser::CurrentUser->agentnums_sql(
    'null_right' => 'View/link unlinked services',
    'table' => 'cust_main'
  );

  #custnum
  if ( $params->{'custnum'} =~ /^(\d+)$/ and $1 ) {
    push @where, "custnum = $1";
  }

  #pkgpart, now properly untainted, can be arrayref
  for my $pkgpart ( $params->{'pkgpart'} ) {
    if ( ref $pkgpart ) {
      my $where = join(',', map { /^(\d+)$/ ? $1 : () } @$pkgpart );
      push @where, "cust_pkg.pkgpart IN ($where)" if $where;
    }
    elsif ( $pkgpart =~ /^(\d+)$/ ) {
      push @where, "cust_pkg.pkgpart = $1";
    }
  }

  #routernum, can be arrayref
  for my $routernum ( $params->{'routernum'} ) {
    # this no longer uses addr_block
    if ( ref $routernum and grep { $_ } @$routernum ) {
      my $in = join(',', map { /^(\d+)$/ ? $1 : () } @$routernum );
      my @orwhere;
      push @orwhere, "svc_broadband.routernum IN ($in)" if $in;
      push @orwhere, "svc_broadband.routernum IS NULL" 
        if grep /^none$/, @$routernum;
      push @where, '( '.join(' OR ', @orwhere).' )';
    }
    elsif ( $routernum =~ /^(\d+)$/ ) {
      push @where, "svc_broadband.routernum = $1";
    }
    elsif ( $routernum eq 'none' ) {
      push @where, "svc_broadband.routernum IS NULL";
    }
  }

  #sector and tower, as above
  my @where_sector = $class->tower_sector_sql($params);
  if ( @where_sector ) {
    push @where, @where_sector;
    push @from, 'LEFT JOIN tower_sector USING ( sectornum )';
  }
 
  #svcnum
  if ( $params->{'svcnum'} =~ /^(\d+)$/ ) {
    push @where, "svcnum = $1";
  }

  #svcpart
  if ( $params->{'svcpart'} =~ /^(\d+)$/ ) {
    push @where, "svcpart = $1";
  }

  #ip_addr
  if ( $params->{'ip_addr'} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/ ) {
    push @where, "ip_addr = '$1'";
  }

  #custnum
  if ( $params->{'custnum'} =~ /^(\d+)$/ and $1) {
    push @where, "custnum = $1";
  }
  
  my $addl_from = join(' ', @from);
  my $extra_sql = '';
  $extra_sql = 'WHERE '.join(' AND ', @where) if @where;
  my $count_query = "SELECT COUNT(*) FROM svc_broadband $addl_from $extra_sql";
  return( {
      'table'   => 'svc_broadband',
      'hashref' => {},
      'select'  => join(', ',
        'svc_broadband.*',
        'part_svc.svc',
        'cust_main.custnum',
        FS::UI::Web::cust_sql_fields($params->{'cust_fields'}),
      ),
      'extra_sql' => $extra_sql,
      'addl_from' => $addl_from,
      'order_by'  => "ORDER BY ".($params->{'order_by'} || 'svcnum'),
      'count_query' => $count_query,
    } );
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

sub search_sql {
  my( $class, $string ) = @_;
  if ( $string =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
    $class->search_sql_field('ip_addr', $string );
  }elsif ( $string =~ /^([a-fA-F0-9]{12})$/ ) {
    $class->search_sql_field('mac_addr', uc($string));
  }elsif ( $string =~ /^(([a-fA-F0-9]{1,2}:){5}([a-fA-F0-9]{1,2}))$/ ) {
    $class->search_sql_field('mac_addr', uc("$2$3$4$5$6$7") );
  } else {
    '1 = 0'; #false
  }
}

=item label

Returns the IP address.

=cut

sub label {
  my $self = shift;
  $self->ip_addr;
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
  $mac_addr =~ s/[-: ]//g;
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
  ;
  return $error if $error;

  if(($self->speed_up || 0) < 0) { return 'speed_up must be positive'; }
  if(($self->speed_down || 0) < 0) { return 'speed_down must be positive'; }

  my $cust_svc = $self->svcnum
                 ? qsearchs('cust_svc', { 'svcnum' => $self->svcnum } )
                 : '';
  my $cust_pkg;
  if ($cust_svc) {
    $cust_pkg = $cust_svc->cust_pkg;
  }else{
    $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $self->pkgnum } );
    return "Invalid pkgnum" unless $cust_pkg;
  }
  my $agentnum = $cust_pkg->cust_main->agentnum if $cust_pkg;

  if ($self->routernum) {
    return "Router ".$self->routernum." does not provide this service"
      unless qsearchs('part_svc_router', { 
        svcpart => $self->cust_svc->svcpart,
        routernum => $self->routernum
    });
  
    my $router = $self->router;
    return "Router ".$self->routernum." does not serve this customer"
      if $router->agentnum and $router->agentnum != $agentnum;

    if ( $router->auto_addr ) {
      my $error = $self->assign_ip_addr;
      return $error if $error;
    }
    else {
      $self->blocknum('');
    }
  } # if $self->routernum

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

  $error = $self->_check_ip_addr;
  return $error if $error;

  $self->SUPER::check;
}

=item assign_ip_addr

Assign an address block matching the selected router, and the selected block
if there is one.

=cut

sub assign_ip_addr {
  my $self = shift;
  my @blocks;
  my $ip_addr;

  if ( $self->blocknum and $self->addr_block->routernum == $self->routernum ) {
    # simple case: user chose a block, find an address in that block
    # (this overrides an existing IP address if it's not in the block)
    @blocks = ($self->addr_block);
  }
  elsif ( $self->routernum ) {
    @blocks = $self->router->auto_addr_block;
  }
  else { 
    return '';
  }

  foreach my $block ( @blocks ) {
    if ( $self->ip_addr and $block->NetAddr->contains($self->NetAddr) ) {
      # don't change anything
      return '';
    }
    $ip_addr = $block->next_free_addr;
    last if $ip_addr;
  }
  if ( $ip_addr ) {
    $self->set(ip_addr => $ip_addr->addr);
    return '';
  }
  else {
    return 'No IP address available on this router';
  }
}

sub _check_ip_addr {
  my $self = shift;

  if (not($self->ip_addr) or $self->ip_addr eq '0.0.0.0') {
    return '' if $conf->exists('svc_broadband-allow_null_ip_addr'); 
    return 'IP address required';
  }
#  if (my $dup = qsearchs('svc_broadband', {
#        ip_addr => $self->ip_addr,
#        svcnum  => {op=>'!=', value => $self->svcnum}
#      }) ) {
#    return 'IP address conflicts with svcnum '.$dup->svcnum;
#  }
  '';
}

sub _check_duplicate {
  my $self = shift;

  return "MAC already in use"
    if ( $self->mac_addr &&
         scalar( qsearch( 'svc_broadband', { 'mac_addr', $self->mac_addr } ) )
       );

  '';
}


=item NetAddr

Returns a NetAddr::IP object containing the IP address of this service.  The netmask 
is /32.

=cut

sub NetAddr {
  my $self = shift;
  new NetAddr::IP ($self->ip_addr);
}

=item addr_block

Returns the FS::addr_block record (i.e. the address block) for this broadband service.

=cut

sub addr_block {
  my $self = shift;
  qsearchs('addr_block', { blocknum => $self->blocknum });
}

=item router

Returns the FS::router record for this service.

=cut

sub router {
  my $self = shift;
  qsearchs('router', { routernum => $self->routernum });
}

=back

=item allowed_routers

Returns a list of allowed FS::router objects.

=cut

sub allowed_routers {
  my $self = shift;
  map { $_->router } qsearch('part_svc_router', 
    { svcpart => $self->cust_svc->svcpart });
}


#class method
sub _upgrade_data {
  my $class = shift;

  # set routernum to addr_block.routernum
  foreach my $self (qsearch('svc_broadband', {
      blocknum => {op => '!=', value => ''},
      routernum => ''
    })) {
    my $addr_block = $self->addr_block;
    if ( my $routernum = $addr_block->routernum ) {
      $self->set(routernum => $routernum);
      my $error = $self->replace;
      die "error assigning routernum $routernum to service ".$self->svcnum.
          ":\n$error\n"
        if $error;
    }
    else {
      warn "svcnum ".$self->svcnum.
        ": no routernum in address block ".$addr_block->cidr.", skipped\n";
    }
  }
  '';
}

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

