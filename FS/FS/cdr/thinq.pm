package FS::cdr::thinq;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use base qw( FS::cdr );
use Time::Local;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'ThinQ',
  'weight'        => 13,
  'type'          => 'csv',
  'header'        => 1,
  'disabled'      => 0,     #0 default, set to 1 to disable


  'import_fields' => [

    # Date (YYYY-MM-DD)
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d\d(\d\d)?)\-(\d{1,2})\-(\d{1,2})$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $4, $3-1, $1 );
        },

    # Time (HH:MM:SS )
    sub { my($cdr, $time) = @_;
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          $cdr->startdate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    'carrierid',         # carrier_id
    'src',               # from_ani
     skip(5),            # from_lrn
		                     # from_lata
		                     # from_ocn
		                     # from_state
		                     # from_rc
    'dst',               # to_did
    'channel',           # thing_tier
    'userfield',         # callid
    'accountcode',       # account_id
     skip(2),            # tf_profile
		                     # dest_type
    'dst_ip_addr',       # dest
     skip(1),	           # rate
    'billsec',           # billsec
     skip(1),	           #total_charge
  ],  ## end import

);	## end info

sub skip { map { undef } (1..$_[0]) }

1;

__END__
