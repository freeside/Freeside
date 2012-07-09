package FS::cust_main::Location;

use strict;
use vars qw( $DEBUG $me @location_fields );
use FS::Record qw(qsearch qsearchs);
use FS::UID qw(dbh);
use FS::cust_location;

use Carp qw(carp);

$DEBUG = 0;
$me = '[FS::cust_main::Location]';

my $init = 0;
BEGIN {
  # set up accessors for location fields
  if (!$init) {
    no strict 'refs';
    @location_fields = 
      qw( address1 address2 city county state zip country district
        latitude longitude coord_auto censustract censusyear geocode );

    foreach my $f (@location_fields) {
      *{"FS::cust_main::Location::$f"} = sub {
        carp "WARNING: tried to set cust_main.$f with accessor" if (@_ > 1);
        shift->bill_location->$f
      };
      *{"FS::cust_main::Location::ship_$f"} = sub {
        carp "WARNING: tried to set cust_main.ship_$f with accessor" if (@_ > 1);
        shift->ship_location->$f
      };
    }
    $init++;
  }
}

#debugging shim--probably a performance hit, so remove this at some point
sub get {
  my $self = shift;
  my $field = shift;
  if ( $DEBUG and grep (/^(ship_)?($field)$/, @location_fields) ) {
    carp "WARNING: tried to get() location field $field";
    $self->$field;
  }
  $self->FS::Record::get($field);
}

=head1 NAME

FS::cust_main::Location - Location-related methods for cust_main

=head1 DESCRIPTION

These methods are available on FS::cust_main objects;

=head1 METHODS

=over 4

=item bill_location

Returns an L<FS::cust_location> object for the customer's billing address.

=cut

sub bill_location {
  my $self = shift;
  $self->hashref->{bill_location} 
    ||= FS::cust_location->by_key($self->bill_locationnum);
}

=item ship_location

Returns an L<FS::cust_location> object for the customer's service address.

=cut

sub ship_location {
  my $self = shift;
  $self->hashref->{ship_location}
    ||= FS::cust_location->by_key($self->ship_locationnum);
}

=item location TYPE

An alternative way of saying "bill_location or ship_location, depending on 
if TYPE is 'bill' or 'ship'".

=cut

sub location {
  my $self = shift;
  return $self->bill_location if $_[0] eq 'bill';
  return $self->ship_location if $_[0] eq 'ship';
  die "bad location type '$_[0]'";
}

=back

=head1 CLASS METHODS

=over 4

=item location_fields

Returns a list of fields found in the location objects.  All of these fields
can be read (but not written) by calling them as methods on the 
L<FS::cust_main> object (prefixed with 'ship_' for the service address 
fields).

=cut

sub location_fields { @location_fields }

sub _upgrade_data {
  my $class = shift;
  eval "use FS::contact;
        use FS::contact_class;
        use FS::contact_phone;
        use FS::phone_type";

  local $FS::cust_location::import = 1;
  local $DEBUG = 0;
  my $error;

  # Step 0: set up contact classes and phone types
  my $service_contact_class = 
    qsearchs('contact_class', { classname => 'Service'})
    || new FS::contact_class { classname => 'Service'};

  if ( !$service_contact_class->classnum ) {
    $error = $service_contact_class->insert;
    die "error creating contact class for Service: $error" if $error;
  }
  my %phone_type = ( # fudge slightly
    daytime => 'Work',
    night   => 'Home',
    mobile  => 'Mobile',
    fax     => 'Fax'
  );
  my $w = 10;
  foreach (keys %phone_type) {
    $phone_type{$_} = qsearchs('phone_type', { typename => $phone_type{$_}})
                      || new FS::phone_type  { typename => $phone_type{$_},
                                               weight   => $w };
    # just in case someone still doesn't have these
    if ( !$phone_type{$_}->phonetypenum ) {
      $error = $phone_type{$_}->insert;
      die "error creating phone type '$_': $error" if $error;
    }
  }

  foreach my $cust_main (qsearch('cust_main', { bill_locationnum => '' })) {
    # Step 1: extract billing and service addresses into cust_location
    my $custnum = $cust_main->custnum;
    my $bill_location = FS::cust_location->new(
      {
        custnum => $custnum,
        map { $_ => $cust_main->get($_) } location_fields()
      }
    );
    $error = $bill_location->insert;
    die "error migrating billing address for customer $custnum: $error"
      if $error;

    $cust_main->set(bill_locationnum => $bill_location->locationnum);

    if ( $cust_main->get('ship_address1') ) {
      my $ship_location = FS::cust_location->new(
        {
          custnum => $custnum,
          map { $_ => $cust_main->get("ship_$_") } location_fields()
        }
      );
      $error = $ship_location->insert;
      die "error migrating service address for customer $custnum: $error"
        if $error;

      $cust_main->set(ship_locationnum => $ship_location->locationnum);

      # Step 2: Extract shipping address contact fields into contact
      my %unlike = map { $_ => 1 }
        grep { $cust_main->get($_) ne $cust_main->get("ship_$_") }
        qw( last first company daytime night fax mobile );

      if ( %unlike ) {
        # then there IS a service contact
        my $contact = FS::contact->new({
          'custnum'     => $custnum,
          'classnum'    => $service_contact_class->classnum,
          'locationnum' => $ship_location->locationnum,
          'last'        => $cust_main->get('ship_last'),
          'first'       => $cust_main->get('ship_first'),
        });
        if ( $unlike{'company'} ) {
          # there's no contact.company field, but keep a record of it
          $contact->set(comment => 'Company: '.$cust_main->get('ship_company'));
        }
        $error = $contact->insert;
        die "error migrating service contact for customer $custnum: $error"
          if $error;

        foreach ( grep { $unlike{$_} } qw( daytime night fax mobile ) ) {
          my $phone = $cust_main->get("ship_$_");
          next if !$phone;
          my $contact_phone = FS::contact_phone->new({
            'contactnum'    => $contact->contactnum,
            'phonetypenum'  => $phone_type{$_}->phonetypenum,
            FS::contact::_parse_phonestring( $phone )
          });
          $error = $contact_phone->insert;
          # die "whose responsible this"
          die "error migrating service contact phone for customer $custnum: $error"
            if $error;
          $cust_main->set("ship_$_" => '');
        }

        $cust_main->set("ship_$_" => '') foreach qw(last first company);
      } #if %unlike
    } #if ship_address1
    else {
      $cust_main->set(ship_locationnum => $bill_location->locationnum);
    }

    # Step 3: Wipe the migrated fields and update the cust_main

    $cust_main->set("ship_$_" => '') foreach location_fields();
    $cust_main->set($_ => '') foreach location_fields();

    $error = $cust_main->replace;
    die "error migrating addresses for customer $custnum: $error"
      if $error;

    # Step 4: set packages at the "default service location" to ship_location
    foreach my $cust_pkg (
      qsearch('cust_pkg', { custnum => $custnum, locationnum => '' })  
    ) {
      # not a location change
      $cust_pkg->set('locationnum', $cust_main->ship_locationnum);
      $error = $cust_pkg->replace;
      die "error migrating package ".$cust_pkg->pkgnum.": $error"
        if $error;
    }

  } #foreach $cust_main
}

=back

=cut

1;
