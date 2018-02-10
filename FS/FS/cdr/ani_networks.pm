package FS::cdr::ani_networks;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use Time::Local;

%info = (
  'name'               => 'ANI NETWORKS',
  'weight'             => 60,
  'type'               => 'fixedlength',
  'fixedlength_format' => [qw(
    call_date_time:14:1:14
    bill_to_number:15:15:29
    translate_number:10:30:39
    originating_number:10:40:49
    originating_lata:3:50:52
    originating_city:30:53:82
    originating_state:2:83:84
    originating_country:4:85:88
    terminating_number:15:89:103
    terminating_lata:3:104:106
    terminating_city:30:107:136
    terminating_state:2:137:138
    terminating_citycode:3:139:141
    terminating_country:4:142:145
    call_type:2:146:147
    call_transport:1:148:148
    account_code:12:149:160
    info_digits:2:161:162
    duration:8:163:170
    wholesale_amount:9:171:179
    cic:4:180:183
    originating_lrn:10:184:193
    terminating_lrn:10:194:203
    originating_ocn:4:204:207
    terminating_ocn:4:208:211
  )],
  'import_fields'      => [

    sub { #call_date and time
     my($cdr, $data, $conf, $param) = @_;
     $data =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ or die "unparsable record_date: $data";
     $cdr->set('calldate', "$2/$3/$1 $4:$5:$6");
    },

    'charged_party',     #bill to number
    '',    			#translate number

    'src', 			#originating number

    '',    			#originating lata
    '',    			#originating city
    '',   			#originating state
    '',   			#originating country

    'dst', 			#terminating number

    '',    			#terminating lata
    '',    			#terminating city
    '',    			#terminating state
    '',    			#terminating city code
    '',    			#terminating country

    '',    			#call type
    '',    			#call transport
    'accountcode',       #account code
    '',    			#info digits
    'duration',    		#duration
    '',    			#wholesale amount
    '',    			#cic
    'src_lrn',    		#originating lrn
    'dst_lrn',    		#terminating lrn
    '',    			#originating ocn
    '',    			#terminating ocn

  ],

);

1;