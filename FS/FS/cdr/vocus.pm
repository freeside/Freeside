package FS::cdr::vocus;

use strict;
use vars qw( @ISA %info $CDR_TYPES );
use FS::cdr qw( _cdr_date_parse );
use FS::Record qw( qsearch );


@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Vocus',
  'weight'        => 120,  
  'import_fields' => [

    #The first column is reserved for future use.
    skip(1),
    #The second column is the call identifier generated on our system.
    'uniqueid',
    #The third column is the date of the call in UTC.
    'startdate',
    #The fourth column is the time of the call in UTC.
    sub {
      # combine cols 3 & 4 and parse
      my($cdr, $time, $conf, $param) = @_;
      $cdr->startdate(_cdr_date_parse($cdr->startdate.' '.$time, gmt => 1));
    },
    #The fifth column is for Vocus use.
    skip(1),
    #The sixth column is the call duration in seconds.
    'billsec',
    #The seventh column is the calling number presented to our soft switch in E164 format.
    'src',
    #The eight column is the called number presented to our soft switch in E164 format.
    'dst',
    #The ninth column is the time and date at which the call was rated and the
    #  CDR generated in our system. It's just there for your information.
    skip(1),
    #The tenth column is the SZU of the calling party.
    'upstream_src_regionname',
    #The eleventh column is the SZU of the called party, if applicable.
    'upstream_dst_regionname',
    #The twelfth column is the tariff type - Mobile, Regional, International,
    #etc. This matches up with the tariff types under the Voice Access Point on your bill.
    sub {
      my($cdr, $cdrtypename, $conf, $param) = @_;
      return unless length($cdrtypename);
      _init_cdr_types();
      die "no matching cdrtypenum for $cdrtypename"
        unless defined $CDR_TYPES->{$cdrtypename};
      $cdr->cdrtypenum($CDR_TYPES->{$cdrtypename});
    },
    #The thirteenth column is the cost of the call, ex GST.
    'upstream_price',

  ],
);

sub skip { map {''} (1..$_[0]) }

sub _init_cdr_types {
  unless ($CDR_TYPES) {
    $CDR_TYPES = {};
    foreach my $cdr_type ( qsearch('cdr_type') ) {
      die "multiple cdr_types with same cdrtypename".$cdr_type->cdrtypename
        if defined $CDR_TYPES->{$cdr_type->cdrtypename};
      $CDR_TYPES->{$cdr_type->cdrtypename} = $cdr_type->cdrtypenum;
    }
  }
}

1;

