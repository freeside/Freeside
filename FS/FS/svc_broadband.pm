package FS::svc_broadband;

use strict;
use vars qw(@ISA $conf);
use FS::Record qw( qsearchs qsearch dbh );
use FS::svc_Common;
use FS::cust_svc;
use FS::addr_block;
use NetAddr::IP;

@ISA = qw( FS::svc_Common );

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
    'fields' => {
      'description' => 'Descriptive label for this particular device.',
      'speed_down'  => 'Maximum download speed for this service in Kbps.  0 denotes unlimited.',
      'speed_up'    => 'Maximum upload speed for this service in Kbps.  0 denotes unlimited.',
      'ip_addr'     => 'IP address.  Leave blank for automatic assignment.',
      'blocknum'    => 'Address block.',
    },
  };
}

sub table { 'svc_broadband'; }

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

sub search_sql {
  my( $class, $string ) = @_;
  if ( $string =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
    $class->search_sql_field('ip_addr', $string );
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

=cut

# Standard FS::svc_Common::insert

=item delete

Delete this record from the database.

=cut

# Standard FS::svc_Common::delete

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

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

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_foreign_key('blocknum', 'addr_block', 'blocknum')
    || $self->ut_textn('description')
    || $self->ut_number('speed_up')
    || $self->ut_number('speed_down')
    || $self->ut_ipn('ip_addr')
    || $self->ut_hexn('mac_addr')
    || $self->ut_hexn('auth_key')
    || $self->ut_floatn('latitude')
    || $self->ut_floatn('longitude')
    || $self->ut_floatn('altitude')
    || $self->ut_textn('vlan_profile')
  ;
  return $error if $error;

  if($self->speed_up < 0) { return 'speed_up must be positive'; }
  if($self->speed_down < 0) { return 'speed_down must be positive'; }

  if($self->latitude < -90 || $self->latitude > 90) {
    return 'latitude must be between -90 and 90';
  }
  if($self->longitude < -180 || $self->longitude > 180) {
    return 'longitude must be between -180 and 180';
  }

  if (not($self->ip_addr) or $self->ip_addr eq '0.0.0.0') {
    my $next_addr = $self->addr_block->next_free_addr;
    if ($next_addr) {
      $self->ip_addr($next_addr->addr);
    } else {
      return "No free addresses in addr_block (blocknum: ".$self->blocknum.")";
    }
  }

  # This should catch errors in the ip_addr.  If it doesn't,
  # they'll almost certainly not map into the block anyway.
  my $self_addr = $self->NetAddr; #netmask is /32
  return ('Cannot parse address: ' . $self->ip_addr) unless $self_addr;

  my $block_addr = $self->addr_block->NetAddr;
  unless ($block_addr->contains($self_addr)) {
    return 'blocknum '.$self->blocknum.' does not contain address '.$self->ip_addr;
  }

  my $router = $self->addr_block->router 
    or return 'Cannot assign address from unallocated block:'.$self->addr_block->blocknum;
  if(grep { $_->routernum == $router->routernum} $self->allowed_routers) {
  } # do nothing
  else {
    return 'Router '.$router->routernum.' cannot provide svcpart '.$self->svcpart;
  }

  $self->SUPER::check;
}

=item NetAddr

Returns a NetAddr::IP object containing the IP address of this service.  The netmask 
is /32.

=cut

sub NetAddr {
  my $self = shift;
  return new NetAddr::IP ($self->ip_addr);
}

=item addr_block

Returns the FS::addr_block record (i.e. the address block) for this broadband service.

=cut

sub addr_block {
  my $self = shift;

  return qsearchs('addr_block', { blocknum => $self->blocknum });
}

=back

=item allowed_routers

Returns a list of allowed FS::router objects.

=cut

sub allowed_routers {
  my $self = shift;

  return map { $_->router } qsearch('part_svc_router', { svcpart => $self->svcpart });
}

=head1 BUGS

The business with sb_field has been 'fixed', in a manner of speaking.

=head1 SEE ALSO

FS::svc_Common, FS::Record, FS::addr_block,
FS::part_svc, schema.html from the base documentation.

=cut

1;

