package FS::part_export::cust_location_http;

use strict;
use base qw( FS::part_export::http );
use vars qw( %options %info );

use FS::cust_main::Location;

my @location_fields = ( qw( custnum prospectnum ), FS::cust_main::Location->location_fields );

tie %options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'location_url'   => { label   => 'Location URL' },
  'package_url'    => { label   => 'Package URL' },
  'ssl_no_verify'  => { label => 'Skip SSL certificate validation',
                        type  => 'checkbox',
                      },
  'include_fields' => { 'label' => 'Include fields',
                        'type'  => 'select',
                        'multiple' => 1,
                        'options' => [ @location_fields ] },
  'success_regexp' => {
    label  => 'Success Regexp',
    default => '',
  },
;

%info = (
  'svc'     => [qw( cust_location )],
  'desc'    => 'Send an HTTP or HTTPS GET or POST request, for customer locations',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END',
Send an HTTP or HTTPS GET or POST to the specified URLs on customer location
creation/update (action 'location') and package location assignment/change (action 'package').
Always sends locationnum, action and any fields specified in the 'Include fields' 
export option.  Action 'package' also sends pkgnum and old_pkgnum (because location
changes usually instigate a pkgnum change.)  Action 'location' only sends on replace 
if one of the specified fields changed.  Leave a URL blank to skip that action.
For HTTPS support, <a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a> is required.
END
);

# we don't do anything on deletion because we generally don't delete locations
#
# we don't send blank custnum/prospectnum because we do a lot of inserting/replacing 
#   with blank values and then immediately overwriting, but that unfortunately
#   makes it difficult to indicate if this is the first time we've sent the location
#   to the customer--hence we don't distinguish creation from update in the cgi vars

# gets invoked by FS::part_export::http _export_insert
sub _export_command {
  my( $self, $action, $cust_location ) = ( shift, shift, shift );

  # redundant--cust_location exports don't get invoked by cust_location->delete,
  # or by any status trigger, but just to be clear, since http export has other actions...
  return '' unless $action eq 'insert';

  $self->_http_queue_standard(
    'action' => 'location',
    map { $_ => $cust_location->get($_) } ('locationnum', $self->_include_fields)
  );

}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  my $changed = 0;
  foreach my $field ($self->_include_fields) {
    next if $new->get($field) eq $old->get($field);
    next if ($field =~ /latitude|longitude/) and $new->get($field) == $old->get($field);
    $changed = 1;
    last;
  }
  return '' unless $changed;

  $self->_http_queue_standard(
    'action' => 'location',
    map { $_ => $new->get($_) } ('locationnum', $self->_include_fields)
  );
}

# not to be confused with export_pkg_change, which is for svcs
sub export_pkg_location {
  my( $self, $cust_pkg ) = ( shift, shift, shift );

  return '' unless $cust_pkg->locationnum;

  my $cust_location = $cust_pkg->cust_location;

  $self->_http_queue_standard(
    'action' => 'package',
    (map { $_ => $cust_pkg->get($_) } ('pkgnum', 'change_pkgnum', 'locationnum')),
    (map { $_ => $cust_location->get($_) } $self->_include_fields),
  );
}

sub _http_queue_standard {
  my $self = shift;
  my %opts = @_;
  my $url;
  if ($opts{'action'} eq 'location') {
    $url = $self->option('location_url');
    return '' unless $url;
  } elsif ($opts{'action'} eq 'package') {
    $url = $self->option('package_url');
    return '' unless $url;
  } else {
    return "Bad action ".$opts{'action'};
  }
  $self->http_queue( '',
    ( $self->option('ssl_no_verify') ? 'ssl_no_verify' : '' ),
    $self->option('method'),
    $url,
    $self->option('success_regexp'),
    %opts
  );
}

sub _include_fields {
  my $self = shift;
  split( /\s+/, $self->option('include_fields') );
}

1;
