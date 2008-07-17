package FS::cdr::taqua;

use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Taqua',
  'weight'        => 130,
  'header'        => 1,
  'import_fields' => [  #some of these are kind arbitrary...
    sub { my($cdr, $field) = @_; },       #XXX interesting RecordType
             # easy to fix: Can't find cdr.cdrtypenum 1 in cdr_type.cdrtypenum

    sub { my($cdr, $field) = @_; },             #all10#RecordVersion
    sub { my($cdr, $field) = @_; },       #OrigShelfNumber
    sub { my($cdr, $field) = @_; },       #OrigCardNumber
    sub { my($cdr, $field) = @_; },       #OrigCircuit
    sub { my($cdr, $field) = @_; },       #OrigCircuitType
    'uniqueid',                           #SequenceNumber
    'accountcode',                        #SessionNumber
    'src',                                #CallingPartyNumber
    'dst',                                #CalledPartyNumber
    _cdr_date_parser_maker('startdate'),  #CallArrivalTime
    _cdr_date_parser_maker('enddate'),    #CallCompletionTime

    #Disposition
    #sub { my($cdr, $d ) = @_; $cdr->disposition( $disposition{$d}): },
    'disposition',
                                          #  -1 => '',
                                          #   0 => '',
                                          # 100 => '',
                                          # 101 => '',
                                          # 102 => '',
                                          # 103 => '',
                                          # 104 => '',
                                          # 105 => '',
                                          # 201 => '',
                                          # 203 => '',

    _cdr_date_parser_maker('answerdate'), #DispositionTime
    sub { my($cdr, $field) = @_; },       #TCAP
    sub { my($cdr, $field) = @_; },       #OutboundCarrierConnectTime
    sub { my($cdr, $field) = @_; },       #OutboundCarrierDisconnectTime

    #TermTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'dstchannel',                         #TermTrunkGroup


    sub { my($cdr, $field) = @_; },       #TermShelfNumber
    sub { my($cdr, $field) = @_; },       #TermCardNumber
    sub { my($cdr, $field) = @_; },       #TermCircuit
    sub { my($cdr, $field) = @_; },       #TermCircuitType
    sub { my($cdr, $field) = @_; },       #OutboundCarrierId
    'charged_party',                      #BillingNumber
    sub { my($cdr, $field) = @_; },       #SubscriberNumber
    'lastapp',                            #ServiceName
    sub { my($cdr, $field) = @_; },       #some weirdness #ChargeTime
    'lastdata',                           #ServiceInformation
    sub { my($cdr, $field) = @_; },       #FacilityInfo
    sub { my($cdr, $field) = @_; },             #all 1900-01-01 0#CallTraceTime
    sub { my($cdr, $field) = @_; },             #all-1#UniqueIndicator
    sub { my($cdr, $field) = @_; },             #all-1#PresentationIndicator
    sub { my($cdr, $field) = @_; },             #empty#Pin
    sub { my($cdr, $field) = @_; },       #CallType
    sub { my($cdr, $field) = @_; },           #Balt/empty #OrigRateCenter
    sub { my($cdr, $field) = @_; },           #Balt/empty #TermRateCenter

    #OrigTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'channel',                            #OrigTrunkGroup

    'userfield',                                #empty#UserDefined
    sub { my($cdr, $field) = @_; },             #empty#PseudoDestinationNumber
    sub { my($cdr, $field) = @_; },             #all-1#PseudoCarrierCode
    sub { my($cdr, $field) = @_; },             #empty#PseudoANI
    sub { my($cdr, $field) = @_; },             #all-1#PseudoFacilityInfo
    sub { my($cdr, $field) = @_; },       #OrigDialedDigits
    sub { my($cdr, $field) = @_; },             #all-1#OrigOutboundCarrier
    sub { my($cdr, $field) = @_; },       #IncomingCarrierID
    'dcontext',                           #JurisdictionInfo
    sub { my($cdr, $field) = @_; },       #OrigDestDigits
    sub { my($cdr, $field) = @_; },       #huh?#InsertTime
    sub { my($cdr, $field) = @_; },       #key
    sub { my($cdr, $field) = @_; },             #empty#AMALineNumber
    sub { my($cdr, $field) = @_; },             #empty#AMAslpID
    sub { my($cdr, $field) = @_; },             #empty#AMADigitsDialedWC
    sub { my($cdr, $field) = @_; },       #OpxOffHook
    sub { my($cdr, $field) = @_; },       #OpxOnHook

        #acctid - primary key
  #AUTO #calldate - Call timestamp (SQL timestamp)
#clid - Caller*ID with text
        #XXX src - Caller*ID number / Source number
        #XXX dst - Destination extension
        #dcontext - Destination context
        #channel - Channel used
        #dstchannel - Destination channel if appropriate
        #lastapp - Last application if appropriate
        #lastdata - Last application data
        #startdate - Start of call (UNIX-style integer timestamp)
        #answerdate - Answer time of call (UNIX-style integer timestamp)
        #enddate - End time of call (UNIX-style integer timestamp)
  #HACK#duration - Total time in system, in seconds
  #HACK#XXX billsec - Total time call is up, in seconds
        #disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
#INT amaflags - What flags to use: BILL, IGNORE etc, specified on a per channel basis like accountcode.
        #accountcode - CDR account number to use: account

        #uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)
        #userfield - CDR user-defined field

        #X cdrtypenum - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
        #XXX charged_party - Service number to be billed
#upstream_currency - Wholesale currency from upstream
#X upstream_price - Wholesale price from upstream
#upstream_rateplanid - Upstream rate plan ID
#rated_price - Rated (or re-rated) price
#distance - km (need units field?)
#islocal - Local - 1, Non Local = 0
#calltypenum - Type of call - see FS::cdr_calltype
#X description - Description (cdr_type 7&8 only) (used for cust_bill_pkg.itemdesc)
#quantity - Number of items (cdr_type 7&8 only)
#carrierid - Upstream Carrier ID (see FS::cdr_carrier)
#upstream_rateid - Upstream Rate ID

        #svcnum - Link to customer service (see FS::cust_svc)
        #freesidestatus - NULL, done (or something)
  ],
);

1;
