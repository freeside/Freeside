package FS::part_export::cust_location_http;

use strict;
use base qw( FS::part_export::http );
use vars qw( %options %info );

my @location_fields = qw(
  custnum
  address1
  address2
  city
  state
  zip
  country
  locationname
  county
  latitude
  longitude
  prospectnum
  location_type
  location_number
  location_kind
  geocode
  district
  censusyear
  incorporated
);

tie %options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'url'    => { label   => 'URL', default => 'http://', },
  'ssl_no_verify' => { label => 'Skip SSL certificate validation',
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
Send an HTTP or HTTPS GET or POST to the specified URL on customer location insert
or replace.  Always sends cgi fields action ('insert' or 'replace') and locationnum,
as well as any fields specified below.  Only sends on replace if one of the
specified fields changed.
For HTTPS support, <a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a> is required.
END
);

sub http_queue_standard {
  my $self = shift;
  $self->http_queue( '',
    ( $self->option('ssl_no_verify') ? 'ssl_no_verify' : '' ),
    $self->option('method'),
    $self->option('url'),
    $self->option('success_regexp'),
    @_
  );
}

sub _include_fields {
  my $self = shift;
  split( /\s+/, $self->option('include_fields') );
}

sub _export_command {
  my( $self, $action, $cust_location ) = ( shift, shift, shift );

  return '' unless $action eq 'insert';

  $self->http_queue_standard(
    'action' => $action,
    map { $_ => $cust_location->get($_) } ('locationnum', $self->_include_fields)
  );

}

# currently, only custnum can change (when converting prospect to customer)
# but using more generic logic for ease of adding other changeable fields
sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  my $changed = 0;
  foreach my $field ($self->_include_fields) {
    next if $new->get($field) eq $old->get($field);
    next if ($field =~ /latitude|longitude/) and $new->get($field) == $old->get($field);
    $changed = 1;
  }
  return '' unless $changed;

  $self->http_queue_standard(
    'action' => 'replace',
    map { $_ => $new->get($_) } ('locationnum', $self->_include_fields)
  );
}

1;
