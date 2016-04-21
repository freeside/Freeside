package FS::part_export::cust_location_http;

use strict;
use base qw( FS::part_export::http );
use vars qw( %options %info );

my @location_fields = qw(
  custnum
  prospectnum
  locationname
  address1
  address2
  city
  county
  state
  zip
  country
  latitude
  longitude
  censustract
  censusyear
  district
  geocode
  location_type
  location_number
  location_kind
  incorporated
);

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
  'location_data'  => { 'label'   => 'Location data',
                        'type'    => 'textarea' },
  'package_data'   => { 'label'   => 'Package data',
                        'type'    => 'textarea' },
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
Leave a URL blank to skip that action.
Always sends locationnum, action, and fields specified in the export options.
Action 'package' also sends pkgnum and change_pkgnum (the previous pkgnum,
because location changes usually instigate a pkgnum change.)
Simple field values can be selected in 'Include fields', and more complex
values can be specified in the data field options as perl code using vars
$cust_location, $cust_main and (where relevant) $cust_pkg.
Action 'location' only sends on update if a specified field changed.
Note that scheduled future package changes are currently sent when the change is scheduled
(this may not be the case in future versions of this export.)
For HTTPS support, <a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a> is required.
END
);

# we don't do anything on deletion because we generally don't delete locations
#
# we don't send blank custnum/prospectnum because we do a lot of inserting/replacing 
#   with blank values and then immediately overwriting, but that unfortunately
#   makes it difficult to indicate if this is the first time we've sent the location
#   to the customer--hence we don't distinguish insert from update in the cgi vars

# gets invoked by FS::part_export::http _export_insert
sub _export_command {
  my( $self, $action, $cust_location ) = @_;

  # redundant--cust_location exports don't get invoked by cust_location->delete,
  # or by any status trigger, but just to be clear, since http export has other actions...
  return '' unless $action eq 'insert';

  $self->_http_queue_standard(
    'action' => 'location',
    (map { $_ => $cust_location->get($_) } ('locationnum', $self->_include_fields)),
    $self->_eval_replace('location_data',$cust_location,$cust_location->cust_main),
  );

}

sub _export_replace {
  my( $self, $new, $old ) = @_;

  my $changed = 0;

  # even if they don't want custnum/prospectnum exported,
  # inserts that lack custnum/prospectnum don't trigger exports,
  # so we might not have previously reported these
  $changed = 1 if $new->custnum && !$old->custnum;
  $changed = 1 if $new->prospectnum && !$old->prospectnum;

  foreach my $field ($self->_include_fields) {
    last if $changed;
    next if $new->get($field) eq $old->get($field);
    next if ($field =~ /latitude|longitude/) and $new->get($field) == $old->get($field);
    $changed = 1;
  }

  my %old_eval;
  unless ($changed) {
    %old_eval = $self->_eval_replace('location_data', $old, $old->cust_main),
  }

  my %eval = $self->_eval_replace('location_data', $new, $new->cust_main);

  foreach my $key (keys %eval) {
    last if $changed;
    next if $eval{$key} eq $old_eval{$key};
    $changed = 1;
  }

  return '' unless $changed;

  $self->_http_queue_standard(
    'action' => 'location',
    (map { $_ => $new->get($_) } ('locationnum', $self->_include_fields)),
    %eval,
  );
}

# not to be confused with export_pkg_change, which is for svcs
sub export_pkg_location {
  my ($self, $cust_pkg) = @_;

  return '' unless $cust_pkg->locationnum;

  my $cust_location = $cust_pkg->cust_location;

  $self->_http_queue_standard(
    'action' => 'package',
    (map { $_ => $cust_pkg->get($_) } ('pkgnum', 'change_pkgnum', 'locationnum')),
    (map { $_ => $cust_location->get($_) } $self->_include_fields),
    $self->_eval_replace('package_data',$cust_location,$cust_pkg->cust_main,$cust_pkg),
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

sub _eval_replace {
  my ($self,$option,$cust_location,$cust_main,$cust_pkg) = @_;
  return
    map {
      /^\s*(\S+)\s+(.*)$/ or /()()/;
      my( $field, $value_expression ) = ( $1, $2 );
      my $value = eval $value_expression;
      die $@ if $@;
      ( $field, $value );
    } split(/\n/, $self->option($option) );
}

1;
