package FS::cust_pkg::API;

use strict;

use FS::cust_location::API;

sub API_getinfo {
  my $self = shift;

  +{ ( map { $_=>$self->$_ } $self->fields ),
   };

}

# currently only handles location change...
# eventually have it handle all sorts of package changes
sub API_change {
  my $self = shift;
  my %opt = @_;

  return { 'error' => 'Cannot change canceled package' }
    if $self->cancel;

  my %changeopt;

  # update location--accepts raw fields OR location
  my %location_hash;
  foreach my $field (FS::cust_location::API::API_editable_fields()) {
    $location_hash{$field} = $opt{$field} if $opt{$field};
  }
  return { 'error' => 'Cannot pass both locationnum and location fields' }
    if $opt{'locationnum'} && %location_hash;

  if (%location_hash) {
    my $cust_location = FS::cust_location->new({
      'custnum' => $self->custnum,
      %location_hash,
    });
    $changeopt{'cust_location'} = $cust_location;
  } elsif ($opt{'locationnum'}) {
    $changeopt{'locationnum'} = $opt{'locationnum'};
  }

  # not quite "nothing changed" because passed changes might be identical to current record,
  #   we don't currently check for that, don't want to imply that we do...but maybe we should?
  return { 'error' => 'No changes passed to method' }
    unless $changeopt{'cust_location'} || $changeopt{'locationnum'};

  $changeopt{'keep_dates'} = 1;

  my $pkg_or_error = $self->change( \%changeopt );
  my $error = ref($pkg_or_error) ? '' : $pkg_or_error;

  return { 'error' => $error } if $error;

  # return all fields?  we don't yet expose them through FS::API
  return { map { $_ => $pkg_or_error->get($_) } qw( pkgnum locationnum ) };

}

1;
