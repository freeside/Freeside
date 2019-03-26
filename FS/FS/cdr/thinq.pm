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

=head1 NAME

FS::cdr::thinq - ThinQ cdr import.

=head1 DESCRIPTION

https://support.thinq.com/hc/en-us/articles/229251987-Defining-the-CDR-for-Origination

File format is csv, fields below.

01  date         - YYYY-MM-DD  2019-03-04
02  time         - HH:MM:SS  19:40:31
03  carrier_id   - thinq id number for each carrier  4
04  from_ani     - number dialed from  14055343879
05  from_lrn     - 10 digit number to identify CO switch port  14056269999
06  from_lata    - originating LATA  536
07  from_ocn     - operating company number assigned by NECA  6534
08  from_state   - originating state (US)  OK
09  from_rc      - originating rate center  "OKLA CITY"
10  to_did       - called number  17312018150
11  thinq_tier   - tier of thinq provider (1,2,3)  1
12  callid       - unique idenitifer for a call  960773443_66972652@206.147.84.26
13  account_id   - thinq account identifier  13840
14  tf_profile   - TFLCR profile used for inbound TF traffic  <null>
15  dest_type    - IP, PSN, ?  IP
16  dest         - pbx IP address for IP routed calls  192.151.131.17
17  rate         - charge per minute  0.00250000
18  billsec      - billable seconds  6
19  total_charge - charge for this call  0.00025000

=cut