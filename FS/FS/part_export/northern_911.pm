package FS::part_export::northern_911;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch dbh);
use base 'FS::part_export';
use Data::Dumper;

tie my %options, 'Tie::IxHash',
  'vendor_code'   => { label=>'Northern 911 vendor code' },
  'password'      => { label=>'API passcode' },
  'test_mode'     => { label=>'Test mode',
                       type =>'checkbox' },
  'debug'         => { label=>'Enable debugging',
                       type =>'checkbox' },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision E911 to Northern 911',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/WebService-Northern911">WebService::Northern911</a>
from CPAN.
END
);

sub client {
  my $self = shift;

  if (!$self->get('client')) {
    local $@;
    eval "use WebService::Northern911";
    return "error loading WebService::Northern911 ($@)" if $@;
    $self->set('client',
      WebService::Northern911->new(
        vendor_code => $self->option('vendor_code'),
        password    => $self->option('password'),
        live        => ( $self->option('test_mode') ? 0 : 1),
      )
    );
  }

  return $self->get('client');
}

sub export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  my %location_hash = $svc_phone->location_hash;
  $location_hash{address1} =~ /^(\w+) +(.*)$/;

  my %customer = (
    'PHONE_NUMBER'        => $svc_phone->phonenum,
    'STREET_NUMBER'       => $1,
    'STREET_NAME'         => $2,
    'CITY'                => $location_hash{city},
    'PROVINCE_STATE'      => $location_hash{state},
    'POSTAL_CODE_ZIP'     => $location_hash{zip},
    'OTHER_ADDRESS_INFO'  => $location_hash{address2},
  );
  my $phone_name = $svc_phone->phone_name;
  if ( $phone_name ) {
    # could be a personal name or a business...
    if ( $svc_phone->e911_class and
        grep { $_ eq $svc_phone->e911_class }
         ( 2, 4, 5, 6, 7, 0, 'A', 'D', 'E', 'K')
       )
    {
      # one of the "Business" classes, Centrex, a payphone, or 
      # VoIP Enterprise class
      $customer{'LAST_NAME'} = $phone_name;
    } else {
      # assume residential, and try (inaccurately) to make a first/last
      # name out of it.
      @customer{'FIRST_NAME', 'LAST_NAME'} = split(' ', $phone_name, 2);
    }
  } else {
    my $cust_main = $svc_phone->cust_svc->cust_pkg->cust_main;
    if ($cust_main->company) {
      $customer{'LAST_NAME'} = $cust_main->company;
    } else {
      $customer{'LAST_NAME'} = $cust_main->last;
      $customer{'FIRST_NAME'} = $cust_main->first;
    }
  }

  if ($self->option('debug')) {
    warn "\nAddorUpdateCustomer:\n".Dumper(\%customer)."\n\n";
  }
  my $response = $self->client->AddorUpdateCustomer(%customer);
  if (!$response->is_success) {
    return $response->error_message;
  }
  '';
}

sub export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  # except when changing the phone number, exactly like export_insert;
  if ($new->phonenum ne $old->phonenum) {
    my $error = $self->export_delete($old);
    return $error if $error;
  }
  $self->export_insert($new);
}

sub export_delete {
  my ($self, $svc_phone) = (shift, shift);

  if ($self->option('debug')) {
    warn "\nDeleteCustomer:\n".$svc_phone->phonenum."\n\n";
  }
  my $response = $self->client->DeleteCustomer($svc_phone->phonenum);
  if (!$response->is_success) {
    return $response->error_message;
  }
  '';
}

# export_suspend and _unsuspend do nothing

sub export_relocate {
  my ($self, $svc_phone) = (shift, shift);
  $self->export_insert($svc_phone);
}

1;

