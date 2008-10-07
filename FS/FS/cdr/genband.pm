package FS::cdr::genband;

use strict;
use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'GenBand (Tekelec)', #'Genband G6 (Tekelec T6000)',
  'weight'        => 140,
  'type'          => 'fixedlength',
  'fixedlength_format' => [qw(
    Type:2:1:2
    Sequence:4:3:6
    OIDCall:30:7:36
    StartTime:19:37:55
    AnswerTime:19:56:74
    EndTime:19:75:93
    SourceName:30:94:123
    SourceEndName:30:124:153
    SourceCallerID:20:154:173
    SourceCallerName:30:174:203
    DestinationName:30:204:233
    DestinationEndName:30:234:263
    DestCallerID:20:264:283
    DestCallerIDInfo:30:284:313
    DialedDigits:30:314:343
    Billing:30:344:373
    AuthCode:30:374:403
    CallDirection:1:404:404
    ExtendedCall:1:405:405
    ExternalCall:1:406:406
    Duration:9:407:415
    SIPCallID:64:416:479
    IncomingDigits:30:480:509
    OutpulsedDigits:30:510:539
    CarrierIdentificationCode:4:540:543
    CompletionReason:4:544:547
    OriginationPartition:30:548:577
    DestinationPartition:30:578:607
    BilledSourceDID:20:608:628
    VideoCall:1:629:630
  )],
  'import_fields' => [
    sub {}, #Type:2:1:2
    sub {}, #Sequence:4:3:6
    'uniqueid', #OIDCall:30:7:36
    _cdr_date_parser_maker('startdate'), #StartTime:19:37:55
    _cdr_date_parser_maker('answerdate'), #AnswerTime:19:56:74
    _cdr_date_parser_maker('enddate'), #EndTime:19:75:93
    #SourceName:30:94:123
    'channel', #SourceEndName:30:124:153
    'src', #SourceCallerID:20:154:173
    'clid', #SourceCallerName:30:174:203
    #DestinationName:30:204:233
    'dstchannel', #DestinationEndName:30:234:263
    'dst', #DestCallerID:20:264:283
    #DestCallerIDInfo:30:284:313
    #DialedDigits:30:314:343
    #Billing:30:344:373
    #AuthCode:30:374:403
    #CallDirection:1:404:404
    #ExtendedCall:1:405:405
    #ExternalCall:1:406:406
    sub { my( $cdr, $duration ) = @_;
          $cdr->duration($duration);
          $cdr->billsec($duration);   }, #'duration', #Duration:9:407:415
    #SIPCallID:64:416:479
    #IncomingDigits:30:480:509
    #OutpulsedDigits:30:510:539
    #CarrierIdentificationCode:4:540:543
    #CompletionReason:4:544:547
    #OriginationPartition:30:548:577
    #DestinationPartition:30:578:607
    #BilledSourceDID:20:608:628
    #VideoCall:1:629:630
  ],
);
#      acctid - primary key
#       calldate - Call timestamp (SQL timestamp)
#              clid - Caller*ID with text
#              src - Caller*ID number / Source number
#              dst - Destination extension
#       dcontext - Destination context
#              channel - Channel used
#              dstchannel - Destination channel if appropriate
#       lastapp - Last application if appropriate
#       lastdata - Last application data
#              startdate - Start of call (UNIX-style integer timestamp)
#              answerdate - Answer time of call (UNIX-style integer timestamp)
#              enddate - End time of call (UNIX-style integer timestamp)
#              duration - Total time in system, in seconds
#              billsec - Total time call is up, in seconds
#       disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
#       amaflags - What flags to use: BILL, IGNORE etc, specified on a per
#       channel basis like accountcode.
#       accountcode - CDR account number to use: account
#              uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)
#       userfield - CDR user-defined field
#       cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
#       charged_party - Service number to be billed
#       upstream_currency - Wholesale currency from upstream
#       upstream_price - Wholesale price from upstream
#       upstream_rateplanid - Upstream rate plan ID
#       rated_price - Rated (or re-rated) price
#       distance - km (need units field?)
#       islocal - Local - 1, Non Local = 0
#       calltypenum - Type of call - see FS::cdr_calltype
#       description - Description (cdr_type 7&8 only) (used for
#       cust_bill_pkg.itemdesc)
#       quantity - Number of items (cdr_type 7&8 only)
#       carrierid - Upstream Carrier ID (see FS::cdr_carrier)
#       upstream_rateid - Upstream Rate ID
#       svcnum - Link to customer service (see FS::cust_svc)
#       freesidestatus - NULL, done (or something)

1;
