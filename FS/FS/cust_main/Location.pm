package FS::cust_main::Location;

use strict;
use vars qw( $DEBUG $me @location_fields );
use FS::Record qw(qsearch qsearchs);
use FS::UID qw(dbh);
use FS::Cursor;
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
        latitude longitude coord_auto censustract censusyear geocode
        addr_clean );

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
    ||= FS::cust_location->by_key($self->bill_locationnum)
    # degraded mode--let the system keep running during upgrades
    ||  FS::cust_location->new({
        map { $_ => $self->get($_) } @location_fields
      })
}

=item ship_location

Returns an L<FS::cust_location> object for the customer's service address.

=cut

sub ship_location {
  my $self = shift;
  $self->hashref->{ship_location}
    ||= FS::cust_location->by_key($self->ship_locationnum)
    ||  FS::cust_location->new({
        map { $_ => $self->get('ship_'.$_) || $self->get($_) } @location_fields
      })

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
  my %opt = @_;

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
    warn "Creating service contact class.\n";
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
  
  my $num_to_upgrade = FS::cust_main->count('bill_locationnum is null or ship_locationnum is null');
  my $num_jobs = FS::queue->count('job = \'FS::cust_main::Location::process_upgrade_location\' and status != \'failed\'');
  if ( $num_to_upgrade > 0 ) {
    warn "Need to migrate $num_to_upgrade customer locations.\n";

    if ( $opt{queue} ) {
      if ( $num_jobs > 0 ) {
        warn "Upgrade already queued.\n";
      } else {
        warn "Scheduling upgrade.\n";
        my $job = FS::queue->new({ job => 'FS::cust_main::Location::process_upgrade_location' });
        $job->insert;
      }
    } else { #do it now
      process_upgrade_location();
    }

  }
  # repair an error in earlier upgrades
  if (!FS::upgrade_journal->is_done('cust_location_censustract_repair')
       and FS::Conf->new->exists('cust_main-require_censustract') ) {

    foreach my $cust_location (
      qsearch('cust_location', { 'censustract' => '' })
    ) {
      my $custnum = $cust_location->custnum;
      next if !$custnum; # avoid doing this for prospect locations
      my $address1 = $cust_location->address1;
      # find the last history record that had that address
      my $last_h = qsearchs({
          table     => 'h_cust_main',
          extra_sql => " WHERE custnum = $custnum AND address1 = ".
                        dbh->quote($address1) .
                        " AND censustract IS NOT NULL",
          order_by  => " ORDER BY history_date DESC LIMIT 1",
      });
      if (!$last_h) {
        # this is normal; just means it never had a census tract before
        next;
      }
      $cust_location->set('censustract' => $last_h->get('censustract'));
      $cust_location->set('censusyear'  => $last_h->get('censusyear'));
      my $error = $cust_location->replace;
      warn "Error setting census tract for customer #$custnum:\n  $error\n"
        if $error;
    } # foreach $cust_location
    FS::upgrade_journal->set_done('cust_location_censustract_repair');
  }
}

sub process_upgrade_location {
  my $class = shift;

  my $dbh = dbh;
  local $FS::cust_location::import = 1;
  local $FS::UID::AutoCommit = 0;

  my $tax_prefix = 'bill_';
  if ( FS::Conf->new->exists('tax-ship_address') ) {
    $tax_prefix = 'ship_';
  }

  # load some records that were created during the initial upgrade
  my $service_contact_class = 
    qsearchs('contact_class', { classname => 'Service'});

  my %phone_type = (
    daytime => 'Work',
    night   => 'Home',
    mobile  => 'Mobile',
    fax     => 'Fax'
  );
  foreach (keys %phone_type) {
    $phone_type{$_} = qsearchs('phone_type', { typename => $phone_type{$_}});
  }

  my %opt = (
    tax_prefix            => $tax_prefix,
    service_contact_class => $service_contact_class,
    phone_type            => \%phone_type,
  );

  my $search = FS::Cursor->new('cust_main', { bill_locationnum => '' });
  while (my $cust_main = $search->fetch) {
    my $error = $cust_main->upgrade_location(%opt);
    if ( $error ) {
      warn "cust#".$cust_main->custnum.": $error\n";
      $dbh->rollback;
    } else {
      # commit as we go
      $dbh->commit;
    }
  }
}

sub upgrade_location { # instance method
  my $cust_main = shift;
  my %opt = @_;
  my $error;

  # Step 1: extract billing and service addresses into cust_location
  my $custnum = $cust_main->custnum;
  my $bill_location = FS::cust_location->new(
    {
      custnum => $custnum,
      map { $_ => $cust_main->get($_) } location_fields(),
    }
  );
  $bill_location->set('censustract', '');
  $bill_location->set('censusyear', '');
   # properly goes with ship_location; if they're the same, will be set
   # on ship_location before inserting either one
  my $ship_location = $bill_location; # until proven otherwise

  if ( $cust_main->get('ship_address1') ) {
    # detect duplicates
    my $same = 1;
    foreach (location_fields()) {
      if ( length($cust_main->get("ship_$_")) and
           $cust_main->get($_) ne $cust_main->get("ship_$_") ) {
        $same = 0;
      }
    }

    if ( !$same ) {
      $ship_location = FS::cust_location->new(
        {
          custnum => $custnum,
          map { $_ => $cust_main->get("ship_$_") } location_fields()
        }
      );
    } # else it stays equal to $bill_location

    # Step 2: Extract shipping address contact fields into contact
    my %unlike = map { $_ => 1 }
      grep { $cust_main->get($_) ne $cust_main->get("ship_$_") }
      qw( last first company daytime night fax mobile );

    if ( %unlike ) {
      # then there IS a service contact
      my $contact = FS::contact->new({
        'custnum'     => $custnum,
        'classnum'    => $opt{service_contact_class}->classnum,
        'locationnum' => $ship_location->locationnum,
        'last'        => $cust_main->get('ship_last'),
        'first'       => $cust_main->get('ship_first'),
      });
      if ( !$cust_main->get('ship_last') or !$cust_main->get('ship_first') )
      {
        warn "customer $custnum has no service contact name; substituting ".
             "customer name\n";
        $contact->set('last' => $cust_main->get('last'));
        $contact->set('first' => $cust_main->get('first'));
      }

      if ( $unlike{'company'} ) {
        # there's no contact.company field, but keep a record of it
        $contact->set(comment => 'Company: '.$cust_main->get('ship_company'));
      }
      $error = $contact->insert;
      return "error migrating service contact for customer $custnum: $error"
        if $error;

      foreach ( grep { $unlike{$_} } qw( daytime night fax mobile ) ) {
        my $phone = $cust_main->get("ship_$_");
        next if !$phone;
        my $contact_phone = FS::contact_phone->new({
          'contactnum'    => $contact->contactnum,
          'phonetypenum'  => $opt{phone_type}->{$_}->phonetypenum,
          FS::contact::_parse_phonestring( $phone )
        });
        $error = $contact_phone->insert;
        return "error migrating service contact phone for customer $custnum: $error"
          if $error;
        $cust_main->set("ship_$_" => '');
      }

      $cust_main->set("ship_$_" => '') foreach qw(last first company);
    } #if %unlike
  } #if ship_address1

  # special case: should go with whichever location is used to calculate
  # taxes, because that's the one it originally came from
  if ( my $geocode = $cust_main->get('geocode') ) {
    $bill_location->set('geocode' => '');
    $ship_location->set('geocode' => '');

    if ( $opt{tax_prefix} eq 'bill_' ) {
      $bill_location->set('geocode', $geocode);
    } elsif ( $opt{tax_prefix} eq 'ship_' ) {
      $ship_location->set('geocode', $geocode);
    }
  }

  # this always goes with the ship_location (whether it's the same as
  # bill_location or not)
  $ship_location->set('censustract', $cust_main->get('censustract'));
  $ship_location->set('censusyear',  $cust_main->get('censusyear'));

  $error = $bill_location->insert;
  return "error migrating billing address for customer $custnum: $error"
    if $error;

  $cust_main->set(bill_locationnum => $bill_location->locationnum);

  if (!$ship_location->locationnum) {
    $error = $ship_location->insert;
    return "error migrating service address for customer $custnum: $error"
      if $error;
  }

  $cust_main->set(ship_locationnum => $ship_location->locationnum);

  # Step 3: Wipe the migrated fields and update the cust_main

  $cust_main->set("ship_$_" => '') foreach location_fields();
  $cust_main->set($_ => '') foreach location_fields();

  $error = $cust_main->replace;
  return "error migrating addresses for customer $custnum: $error"
    if $error;

  # Step 4: set packages at the "default service location" to ship_location
  my $pkg_search =
    FS::Cursor->new('cust_pkg', { custnum => $custnum, locationnum => '' });
  while (my $cust_pkg = $pkg_search->fetch) {
    # not a location change
    $cust_pkg->set('locationnum', $cust_main->ship_locationnum);
    $error = $cust_pkg->replace;
    return "error migrating package ".$cust_pkg->pkgnum.": $error"
      if $error;
  }
  '';

}


=back

=cut

1;
