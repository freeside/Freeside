package FS::cdr::telstra;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr;

# Telstra LinxOnline eBill format
#


@ISA = qw(FS::cdr);

my %cdr_type_of = (
  'UIR' => 1,
  #'SER' => 7,
  #'OCR' => 8,
);

%info = (
  'name'          => 'Telstra LinxOnline',
  'weight'        => 20,
  'header'        => 1,
  'type'          => 'fixedlength',
  # Wholesale Usage Information Record format
  'fixedlength_format' => [ qw(
    InterfaceRecordType:3:1:3
    ServiceProviderCode:3:4:6
    EventUniqueID:24:7:30
    ProductBillingIdentifier:8:31:38
    BillingElementCode:8:39:46
    InvoiceArrangementID:10:47:56
    ServiceArrangementID:10:57:66
    FullNationalNumber:29:67:95
    OriginatingNumber:25:96:120
    DestinationNumber:25:121:145
    OriginatingDateTime:18:146:163
    ToArea:12:164:175
    UnitQuantityDuration:27:176:202
    CallTypeCode:3:203:205
    RecordType:1:206:206
    Price:15:207:221
    DistanceRangeCode:4:222:225
    ClosedUserGroupID:5:226:230
    ReversalChargeIndicator:1:231:231
    1900CallDescription:30:232:261
    Filler:253:262:514
  )],

  'import_fields' => [
    sub { # InterfaceRecordType: skip everything except usage records
      my ($cdr, $field, $conf, $param) = @_;
      $param->{skiprow} = 1 if !exists($cdr_type_of{$field});
      $cdr->cdrtypenum(1);
    },
    skip(1), # service provider code
    'uniqueid', # event file instance, sequence number, bill file ID
             # together these form a unique record ID
    skip(4), # product billing identifier, billing element, invoice
             # arrangement, service arrangement
    parse_phonenum('charged_party'), 
             # "This is the billable number and represents the 
             # service number transferred to the Service Provider as a 
             # result of Product Redirection."
    parse_phonenum('src'), # OriginatingNumber
    parse_phonenum('dst'), # DestinationNumber
    sub { # OriginatingDate and OriginatingTime, two fields in the spec
      my ($cdr, $date) = @_;
      $date =~ /^(\d{4})(\d{2})(\d{2})\s*(\d{2}):(\d{2}):(\d{2})$/
        or die "unparseable date: $date";
      $cdr->startdate(timelocal($6, $5, $4, $3, $2-1, $1));
    },
    skip(1), #ToArea
    sub { # UnitOfMeasure, Quantity, CallDuration, three fields
      my ($cdr, $field, $conf, $param) = @_;
      my ($unit, $qty, $dur) = ($field =~ /^(.{5})(.{13})(.{9})$/);
      $qty = $qty / 100000; # five decimal places
      if( $unit =~ /^SEC/ ) {
        $cdr->billsec($qty);
        $cdr->duration($qty);
      }
      elsif( $unit =~ /^6SEC/ ) {
        $cdr->billsec($qty*6);
        $cdr->duration($qty*6);
      }
      elsif( $unit =~ /^MIN/ ) {
        $cdr->billsec($qty*60);
        $cdr->duration($qty*60);
      }
      else {
        # For now, ignore units that don't convert to time
        $param->{skiprow} = 1;
      }
    },
    skip(2), # CallTypeCode, RecordType
    sub { # Price
      my ($cdr, $price) = @_;
      $cdr->upstream_price($price / 10000000);
    },
    skip(5),
  ],
);

sub skip {
  map {''} (1..$_[0])
}

sub parse_phonenum {
  my $field = shift;
  return sub {
    my ($cdr, $data) = @_;
    my $phonenum;
    my ($type) = ($data =~ /^(.)/); #network service type
    if ($type eq 'A') {
      # domestic number: area code length, then 10-digit number (maybe 
      # padded with spaces), then extension info if it's the FNN/billable 
      # number
      ($phonenum) = ($data =~ /^.\d(.{0,10})/);
      $phonenum =~ s/\s//g;
    }
    elsif ($type eq 'O') {
      # international number: country code length, then 15-digit number
      ($phonenum) = ($data =~ /^.\d(.{0,15})/);
    }
    else {
      # other, take 18 characters
      ($phonenum) = ($data =~ /^.(.{0,18})/);
    }
    $cdr->setfield($field, $phonenum);
  }
}

1;
