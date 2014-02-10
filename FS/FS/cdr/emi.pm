package FS::cdr::emi;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use Time::Local;
#use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'               => 'EMI (Exchange Message Interface)',
  'weight'             => 60,
  'type'               => 'fixedlength',
  'fixedlength_format' => [qw(
    record_identification:6:1:6
    record_date:6:7:12
    calling_number_length:2:13:14
    calling_number:10:15:24
    overflow_digits:3:25:27
    called_number_length:2:28:29
    called_number:10:30:39
    amount_collected:7:40:46

    UNKNOWN_1:8:47:54

    connect_time:6:55:60
    conversation_time:7:61:67
    method_of_recording:2:68:69

    UNKNOWN_1A:9:70:78

    rate_class:1:79:79
    message_type:1:80:80

    UNKNOWN_2:1:81:81

    indicator_1:1:82:82
    indicator_2:1:83:83
    indicator_3:1:84:84
    indicator_4:1:85:85
    indicator_5:1:86:86
    indicator_6:1:87:87
    indicator_7:1:88:88
    indicator_8:1:89:89
    indicator_9:1:90:90
    indicator_10:1:91:91
    indicator_11:1:92:92
    indicator_12:1:93:93
    indicator_13:1:94:94
    indicator_14:1:95:95
    indicator_15:1:96:96
    indicator_16:1:97:97
    indicator_17:1:98:98
    indicator_18:1:99:99
    indicator_19:1:100:100

    UNKNOWN_3:12:101:112

    billing_number:10:113:122
    calling_city:10:123:132
    calling_state:2:133:134
    called_city:10:135:144
    called_state:2:145:146

    UNKNOWN_4:2:147:148

    settlement_code:1:149:149

    UNKNOWN_5:11:150:160

    ind24:1:161:161

    UNKNOWN_6:49:162:210

    calling_module:4:211:214
    module_value_length:3:215:217
    cai:1:218:218
    account_code:10:219:228

    UNKNOWN_7:30:229:258

    tmod:4:259:262

  )],
  'import_fields'      => [

    sub { # record_identification
      my($cdr, $data, $conf, $param) = @_;
      $cdr->{_record_identification} = $data;
      if ( $data eq '202401' || $data eq '202402' ) { #header/footer
        $param->{skiprow} = 1;
      }
    },

   # _cdr_date_parser_maker('startdate'),  # record_date
   sub { #record_date
     my($cdr, $data, $conf, $param) = @_;
     $data =~ /^(\d\d)(\d\d)(\d\d)$/ or die "unparsable record_date: $data";
     $cdr->{_tmp_year} = "20$1";
     $cdr->{_tmp_mon} = $2;
     $cdr->{_tmp_mday} = $3;
   },

    '', #calling_number_length

    'src', #calling_number

    '', #XXX
    #sub { #overflow_digits... add to dst???
    #  my($cdr, $data, $conf, $param) = @_;
    #  if ( $cdr->{_record_identification} eq '010201' ) {
    #    $cdr->dst( $cdr->dst . $data
    #  }
    #}

    '', #called_number_length

    'dst', #called_number

    sub { #amount_collected
      my($cdr, $data, $conf, $param) = @_;

      $cdr->upstream_price( $data / 1000 );
    },

    '', #UNKNOWN_1

    sub { #connect_time
      my($cdr, $data, $conf, $param) = @_;

     $data =~ /^(\d\d)(\d\d)(\d\d)$/ or die "unparsable connect_time: $data";
     $cdr->startdate( timelocal(
                        $3, $2, $1,
                        $cdr->{_tmp_mday}, $cdr->{_tmp_mon}-1, $cdr->{_tmp_year}
                      )
                    );
    },

    sub { #conversation_time
      my($cdr, $data, $conf, $param) = @_;

       $data =~ /^(\d{6})(\d)$/ or die "unparsable connect_time: $data";

       my $time = $1;
       $time++ if $2 >= 5; #round up if tenths > .5

       $cdr->duration($time);
       $cdr->billsec($time);
    
    },

    '', #method_of_recording

    '', #UNKNOWN_1A

    'upstream_rateplanid', #rate_class

    '', #message_type
#A one-position numeric field that identifies the billing arrangement applicable to the transaction, e.g., sent-paid or collect. Values are as follows: 
#1 = Sent Paid 
#2 = Third Number 
#3 = Calling Card 
#4 = Collect 
#5 = Special Collect/Reverse Billing 
#6 = Coin Paid 
#7 = Unassigned 
#8 = Unassigned 
#9 = Unassigned

    '', #UNKNOWN_2

    '', #indicator_1
#Indicator 1 - Coin/Hotel - Motel - Hospital - University Dorm Room - OUTWATS Out Of Band 
#Value
#Indicates
#Definition 
#1 
#Telephone Company Owned Public Telephone Originated 
#Message originated at a telephone company-owned public telephone station. Included are PUBLIC, SEMIPUBLIC, CHARGE-A-CALL, and INMATE CALLS. 
#2 
#Coin Over Collection 
#Indicates that the AMOUNT COLLECTED exceeds the COIN TARIFF AMOUNT, plus the COIN FEDERAL TAX, plus the STATE TAX (if applicable) plus LOCAL TAX (if applicable) on a COIN PAID MESSAGE. On a OSS COIN MEMO, the value in the AMOUNT COLLECTED field represents the excess collected over the amount due 
#3 
#Coin Undercollection 
#Indicates that the AMOUNT COLLECTED is less than the COIN TARIFF AMOUNT, plus COIN FEDERAL TAX, plus STATE TAX (if applicable), plus LOCAL TAX (if applicable) on a COIN PAID MESSAGE. On a OSS Coin Memo, the value and the AMOUNT COLLECTED field represents the difference between the amount collected and the amount due. 
#4 
#Hotel-Motel-Hospital- University Dorm Room Originated 
#The Message originated at an extension in a hotel, motel, hospital, or university dorm room 
#5 
#OUTWATS Out of Band 
#Message originated at an OUTWATS line and terminated at an out-of-band point. 
#6 
#Non-Hotel-Auto/Voice Quote 
#OSS message originated at a non-hotel business subscribing to automated Voice Charge Quotation Service 
#7 
#IC Carrier Owned Public Telephone Originated 
#Message originated at an IC Carrier owned public telephone station 
#8* 
#Customer Owned Public Telephone Originated 
#Message originated at a customer owned public telephone station. 

    '', #indicator_2
    '', #indicator_3
    '', #indicator_4
    '', #indicator_5
    '', #indicator_6
    '', #indicator_7
    '', #indicator_8
    '', #indicator_9

    '', #indicator_10
#Indicator 10 – Radio Services or IP Services Terminated
#Value
#Indicates
#Definition
#1
#Mobile Non-Roamer Terminated
#Indicates that the transaction terminated at a Mobile Non-Roamer.
#2
#Mobile Roamer Terminated
#Indicates that the transaction terminated at a Mobile Roamer.
#3
#Aircraft Terminated
#Indicates that the transaction terminated through Air/Ground facilities.
#4
#High Speed Train Terminated
#Indicates that the transaction terminated aboard a High Speed Train.
#5
#Marine Terminated
#Indicates that the transaction terminated through Coastal Harbor, VHF, marine facilities.
#6
#MARISAT Terminated
#Indicates that the transaction terminated using Marine Satellite facilities.
#7
#High Seas Terminated Indicates that the transaction Terminated through
#High Seas Marine facilities.
#8
#Cellular Terminated
#Indicates that the transaction is cellular terminated.
#9
#IP Terminated

    '', #indicator_11
    '', #indicator_12
    '', #indicator_13
    '', #indicator_14
    '', #indicator_15
    '', #indicator_16
    '', #indicator_17
    '', #indicator_18

    '', #indicator_19
#Indicator 19 - LATA Identifier 
#Value
#Indicates
#Definition 
#0 
#Not Applicable 
#Valid for Unrated Message (Category 10), Telegram Charge (01-01-14), summary Non-Detail Credit (41-50-01), summary Non-Detail Charge (42-50-01), summary Post-Billing Adjustment Non-Detail (45-50-01) records and 800 Records Recorded at the SSP (01-01-25) records. Also valid for IP records. 
#1 
#IntraLATA - LEC Message 
#Indicates that the message originated and terminated within the same LATA and was for telecommunications services provided by a LEC or traffic transported by facilities belonging to or leased by a LEC. Revenue belongs to the LEC. For Category 11 records, this value indicates IntraLATA only, and not whether IC or LEC carried. This is the preferred value for Category 11 IntraLATA. 
#2 
#InterLATA - IC Message 
#Indicates that the message originated in one LATA and terminated in another LATA and was transported by an IC. Revenue belongs to the IC. For Category 11 records, this value indicates InterLATA only, and not whether IC or LEC carried. This is the preferred value for Category 11 InterLATA. 
#3 
#InterLATA - LEC Message 
#Indicates that the message originated in one LATA and terminated in another LATA and was for telecommunications services provided by a LEC or traffic transported by facilities belonging to or leased by a LEC (e.g., Corridor Traffic or interLATA local traffic, as defined in the local tariff). Revenue belongs to the LEC. For Category 11 records, this value indicates InterLATA only, and not whether IC or LEC carried.
#
#Indicator 24 - Specialized Services 
#Value 
#Indicates 
#Definition 
#1 
#Telecommunications Relay Service 
#Indicates a call was placed using a Telecommunications Relay Service. 
#2 
#Three Way Calling 
#Indicates the message originated as part of the Three Way Calling feature. 
#3 
#Directory Assistance Call Completion 
#Indicates the call was completed as a result of a call to a Directory Assistance Call Completion (DACC). 

    '', #UNKNOWN_3

    'charged_party', #billing_number

    'upstream_src_regionname', #calling_city

    sub { #calling_state
      my($cdr, $data, $conf, $param) = @_;
      $cdr->upstream_src_regionname( $cdr->upstream_src_regionname.', '. $data);
    },

    'upstream_dst_regionname', #called_city

    sub { #called_state
      my($cdr, $data, $conf, $param) = @_;
      $cdr->upstream_dst_regionname( $cdr->upstream_dst_regionname.', '. $data);
    },

    '', #UNKNOWN_4

    '', #settlement_code
#Settlement Code A one-position alphanumeric field used for the classification of messages and revenues. Two levels of detail are defined below: 1. The first set of codes is considered to be the minimum requirement. 2. The second set of codes provide a higher level of detail regarding the origin and termination of the message. This additional level of detail can be used where required and where negotiated between the Sending and Receiving companies.
#
# Minimum Requirements: 6 2. A message between points within the same company’s territory in Canada. Example: Points within the Province of Quebec. J 
#Settlement Code 
#Description 
#5 
#INTER-CANADA 
#A message between points within Canada. (Also see Settlement Codes ‘5’ and ‘8’in the optional, more detailed section below.) 
#LOCAL 
#Identifies a service filed under a Local Exchange Tariff. This value is not valid for Category 11 records when traffic utilizes the IC network. (1+ presubscribed, 101XXXX dialed, etc.) 
#7 
#EAS/EMS (Extended Area Service/Extended Metro Service) This value is to be used for Access Record exchange. 
#8 
#INTRASTATE - U.S./U.S. 
#INTERSTATE - U.S./U.S. 
#A message between points in different states within the United States or its territories (i.e., Puerto Rico, the U. S. Virgin Islands, Guam, American Samoa and the Commonwealth of the Northern Mariana Islands). Examples: New Jersey/Maryland, New York/Puerto Rico, California/Alaska. (Also see Settlement Codes ‘G’ and ‘Q’ in the optional, more detailed descriptions below.) 
#NOTE: This Settlement Code is used for all interstate Radio Link Charges. 
#K 
#INTERNATIONAL - U.S./CANADA 
#A message between a point within the United States and its territories (i.e., Puerto Rico, the U. S. Virgin Islands, Guam, American Samoa and the Commonwealth of the Northern Mariana Islands) and a point in Canada. Example: New York/Quebec. 

    '', #UNKNOWN_5

    '', #ind24
#Indicator 24 - Specialized Services 
#Value 
#Indicates 
#Definition 
#1 
#Telecommunications Relay Service 
#Indicates a call was placed using a Telecommunications Relay Service. 
#2 
#Three Way Calling 
#Indicates the message originated as part of the Three Way Calling feature. 
#3 
#Directory Assistance Call Completion 
#Indicates the call was completed as a result of a call to a Directory Assistance Call Completion (DACC). 

    '', #UNKNOWN_6

    '', #calling_module
#Calling Module contains a 3 digit value that identifies the module plus a one position alpha filed that contains the module version. 

    '', #module_value_length

    '', #cai

    'accountcode', #account_code

    '', #UNKNOWN_7

    '', #tmod

  ],

);

1;

