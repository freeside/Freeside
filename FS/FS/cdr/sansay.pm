package FS::cdr::sansay;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Sansay VSX',
  'weight'        => 135,
  'header'        => 1,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv', #csv (default), fixedlength or xls
  'sep_char'      => ';',   #for csv, defaults to ,
  'disabled'      => 0,     #0 default, set to 1 to disable


  #listref of what to do with each field from the CDR, in order
  'import_fields' => [

    # "Header" (I do not think this means what you think it means)
    #002452502;V1.10;R;

    # Record Sequence Number 9 Unique identification of this record
    'uniqueid',

    '', #Version Number         5 Format version number of records to follow
        #                         "V1.10"
    '', #Record Type            1 Type of CDR being generated
        #                         R ­ Normal CDR record, A - Audit

    # "Body"
    #WithMedia;181-1071459514@192.188.0.28;0001;Mon Dec 15 11:38:34 2003;Mon Dec 15 11:38:41 2003;Mon Dec 15 11:38:48 2003;480;EndedByRemoteUser;3;T;000200;H323;;192.188.0.38;9001;192.188.0.28;f0faff54-2e6c-11d8-8c4b-bd4d562c2265;192.188.0.38;18044;192.188.0.28;10756;G.729b;240;460;6066;14060;0;0;0;000200;H323;;192.188.0.28;8811;192.188.0.38;e83af3d3-1d2d-d811-9f98-003048424934;192.188.0.38;19236;192.188.0.28;10758;G.729b;460;240;14060;6066;0;0;0;F;9001;305;2;15;305000;00000011 44934567 45231267 2300BCC0;8587542200;

    '',         #ConnectionType      16 Type of connection : Media or No Media
    '',         #SessionID           32 Unique ID assigned to the call by
                #                       SSM subsystem
    '', #XXX    #Release Cause       4  2.4 Internal process Release Cause

                    #Cause Code Descriptions
                    #01         Normal answered call
                    #02         No Answer, tear down by originator
                    #03         No answer, tear down by the termination
                    #04         NORMAL_NO_ANSWER, tear down by
                    #           system
                    #402        Service Not Available
                    #403        Termination capability un-compatible
                    #404        Outbound digit translation failed
                    #405        Termination reject for some other reasons
                    #406        Termination Route is blocked
                    #500        Originator is not in the Authorized list
                    #           (source verification failed)
                    #501        Origination digit translation failed
                    #502        Origination direction is not bi-directional or
                    #           inbound
                    #503        Origination is not in service state
                    #600        Max system call handling reached
                    #601        System reject call
                    #602        System outbound digit translation error
                    #           (maybe invalid configuration)
                    #603        System inbound digit translation error
                    #           (Maybe invalid configuration)


    #Start Time of Date  32 Indicates Time of Date when the call
    #                       entered the system
    _cdr_date_parser_maker('startddate'), 

    #Answer Time of Date 32 Indicates TOD when the call was
    #                       answered
    _cdr_date_parser_maker('answerdate'), 

    #Release TOD             32  Indicates the TOD when the call was
    #                            disconnected
    _cdr_date_parser_maker('enddate'), 

    #Minutes West of         32  Minutes West of Greenwich Mean
    #Greenwich Mean Time         Time. Used to calculate the time
    #                            zone.
    '', #XXX use this

    #Release Cause from      32  Release cause string from either H323
    #Protocol Stack              or SIP protocol stack
    #4. Release Cause String (Field #8 in CDR)
    #- a string of text further identifying the teardown circumstance from terminating protocol message.
    '',

    #Binary Value of Release 4   Binary value of the protocol release
    #Cause from Protocol         cause
    #stack
    #
    #3. Release Cause from Stack ( Field # 9 in CDR)
    #- an integer value based on the releasing dialogues protocol.
    #   a.   For a H.323 call leg originated release it will be the real Q.931 value received from the far
    #                side.
    #Some of the Q.931 release causes;
    #3: No route to destination
    #16; Normal Clearing
    #17: User Busy
    #19: NO Answer from User
    #21; Call Rejected
    #28: Address Incomplete
    #34: No Circuit Channel Available
    #....
    #   b.   For a SIP call leg originated release, it's a RFC 3261 release cause value received from the
    #                far side.
    #The following is the list that VSX generated if certain event happen:
    #"400 Parse Failed"                     -      Malformed Message
    #"405 Method Not Allowed"               -      Unsupported Method
    #"480 Temporarily Unavailable"                 -       Overload Throttle Rejection, Max Sessions
    #Exceeded, Demo License Expired, Capacity Exceeded on Route, Radius Server Timeout
    #"415 No valid codec"                   -      No valid codec could be supported between origination and
    #term call legs.
    #"481   Transaction Does Not Exist"     -       Unknown Transaction or Dialog
    #"487   Transaction Terminated"                 -      Origination Cancel
    #"488   ReInvite Rejected"              -       Relay of ReInvite was Rejected
    #"504   Server Time-out"                        -      Internal VSX Failure
    #"500   Sequence Out of Order"                  -      CSeq counter violation
    #  c.    For a VSX system originated release, it an internal release cause for teardown.
    #If the VSX initiates a call teardown, the following cause values and strings are written into the CDR:
    #999,    "Demo Licence Expired!"
    #999,    "VSX Capacity Exceeded"
    #999,    "VSX Operator Reset"
    #999,    "Route Rejected"
    #999,    "Radius Rejected"
    #999,    "Radius Access Timeout"
    #999,    "Gatekeeper Reject"
    #999,    "Enum Server Reject"
    #999,    "Enum Server Timeout"
    #999,    "DNS Server Reject"
    #999,    "DNS/GK Timeout"
    #999,    "Could not allocate media"
    #999,    "No Response to INVITE"
    #999,    "Ring No Answer Timeout"
    #999,    "200 OK Timeout"
    #999,    "Maximum Duration Exceeded"
    #987,    "Termination Capacity Exceeded"
    #987,    "Origination Capacity Exceeded"
    #987,    "Term CPS Capacity Exceeded"
    #987,    "Orig CPS Capacity Exceeded"
    #987,    "Max H323 Legs Exceeded"
    '',

    #1st release dialogue    1   O: origination, T: termination
    #2. 1st Release Dialogue ( Field #10 in CDR)
    #- one character value identifying the side of the call that i
    #        ,,O ­ origination initiated the teardown.
    #        ,,T ­ termination initiated the teardown.
    #        ,,N ­ the VSX internally initiated the teardown.
    '',

    #Trunk ID -- Origination 6   TrunkID for origination GW(resources)
    'accountcode', # right? # use cdr-charged_party-accountcode

    #VoIP Protocol - Origination    6   VoIP protocol for origination dialogue
    '',

    #Origination Source Number     128 Source Number in Origination Dialogue
    'src',

    #Origination Source Host Name 128 FQDN or IP address for Source GW in Origination Dialogue
    'channel',

    #Origination Destination Number 128 Destination Number in Origination
    #Dialogue
    'dst',

    #Origination Destination Host Name 128 FQDN or IP address for Destination
    #GW in Origination Dialogue
    'dstchannel',

    #Origination Call ID     128 Unique ID for the origination dialogue(leg)
    '', #'clid', #? that's not really the same call ID

    #Origination Remote      16  Remote Payload IP address for
    #         Payload IP         origination dialogue
    #         Address
    '',

    #Origination Remote      6   Remote Payload UDP address for
    #         Payload UDP        origination dialogue
    #         Address
    '',

    #Origination Local       16  Local(SG) Payload IP address for
    #         Payload IP         origination dialogue
    #         Address
    '',

    #Origination Local       6   Local(SG) Payload UDP address for
    #         Payload UDP        origination dialogue
    #         Address
    '',

    #Origination Codec List  128 Supported Codec list( separated by
    #                            comma) for origination dialogue
    '',

    #Origination Ingress     10  Number of Ingress( into Sansay
    #         Packets            system) payload packets in
    #                            origination dialogue
    '',

    #Origination Egress      10  Number of Egress( out from Sansay
    #         Packets            system) payload packets in
    #                            origination dialogue
    '',

    #Origination Ingress     10  Number of Ingress( into Sansay
    #         Octets             system) payload octets in origination
    #                            dialogue
    '',

    #Origination Egress      10  Number of Egress( out from Sansay
    #        Octets              system) payload octets in origination
    #                            dialogue
    '',

    #Origination Ingress     10  Number of Ingress( into Sansay
    #        Packet Loss         system) payload packet loss in
    #                            origination dialogue
    '',

    #Origination Ingress     10  Average Ingress( into Sansay system)
    #        Delay               payload packets delay ( in ms) in
    #                            origination dialogue
    '',

    #Origination Ingress     10  Average of Ingress( into Sansay
    #        Packet Jitter       system) payload packet Jitter ( in ms)
    #                            in origination dialogue
    '',

    #Trunk ID -- Termination 6   Trunk ID for termination GW(resources)
    'carrierid',

    #VoIP Protocol -         6   VoIP protocol from termination GW
    #        Termination
    '',

    #Termination Source      128 Source Number in Termination
    #        Number              Dialogue
    '',

    #Termination Source Host 128 FQDN or IP address for Source GW
    #        Name                in Termination Dialogue
    '',

    #Termination Destination 128 Destination Number in Termination
    #        Number              Dialogue
    '',

    #Termination Destination 128 FQDN or IP address for Destination
    #        Host Name           GW in Termination Dialogue
    '',

    #Termination Call ID     128 Unique ID for the termination
    #                            dialogue(leg)
    '',

    #Termination Remote      16  Remote Payload IP address for
    #        Payload IP          termination dialogue
    #        Address
    '',

    #Termination Remote      6   Remote Payload UDP address for
    #        Payload UDP         termination dialogue
    #        Address
    '',

    #Termination Local       16  Local(SG) Payload IP address for
    #        Payload IP          termination dialogue
    #        Address
    '',

    #Termination Local       6   Local(SG) Payload UDP address for
    #        Payload UDP         termination dialogue
    #        Address
    '',

    #Termination Codec List  128 Supported Codec list( separated by
    #                            comma) for termination dialogue
    '',

    #Termination Ingress     10  Number of Ingress( into Sansay
    #        Packets             system) payload packets in
    #                            termination dialogue
    '',

    #Termination Egress      10  Number of Egress( out from Sansay
    #        Packets             system) payload packets in
    #                            termination dialogue
    '',

    #Termination Ingress     10  Number of Ingress( into Sansay
    #        Octets              system) payload octets in
    #                           termination dialogue
    '',

    #Termination Egress      10 Number of Egress( out from Sansay
    #        Octets             system) payload octets in
    #                           termination dialogue
    '',

    #Termination Ingress     10 Number of Ingress( into Sansay
    #        Packet Loss        system) payload packet loss in
    #                           termination dialogue
    '',

    #Termination Ingress     10 Average Ingress( into Sansay system)
    #        Delay              payload packets delay ( in ms) in
    #                           termination dialogue
    '',

    #Termination Ingress     10 Average of Ingress( into Sansay
    #        Packet Jitter      system) payload packet Jitter ( in ms)
    #                           in termination dialogue
    '',

    #Final Route Indication  1  F: Final Route Selection,
    #                           I: Intermediate Route Attempts
    '',

    #Routing Digits          64 Routing Digit (Digit after Inbound
    #                           translation, before Outbound
    #                           Translation). This may also be the
    #                           LRN if LNP feature is enabled
    '',

    #Call Duration in Second 6  Call Duration in Seconds. 0 if this is
    #                           failed call
    'billsec',

    #Post Dial Delay in      6  Post dial delay (from call attempt to
    #        Seconds            ring). 0 if this is failed call
    '',

    #Ring Time in Second     6  Ring Time in Seconds. 0 if this is
    #                           failed call
    '',

    #Duration in milliseconds      10 Call duration in milliseconds.
    '',

    #Conf ID                 36 Unique Conference ID for this call in
    #                           Cisco format
    '',

    #RPID/ANI                32 Inbound Remote Party ID line or
    #                           Proxy Asserted Identity if provided
    'clid', #?

  ],

);

1;

__END__

list of freeside CDR fields, useful ones marked with *

N/A       acctid - primary key
FILLED_IN *[1]   calldate - Call timestamp (SQL timestamp)
DONE       clid - Caller*ID with text
DONE *      src - Caller*ID number / Source number
DONE *      dst - Destination extension
       dcontext - Destination context
DONE       channel - Channel used
DONE       dstchannel - Destination channel if appropriate
       lastapp - Last application if appropriate
       lastdata - Last application data
DONE *      startdate - Start of call (UNIX-style integer timestamp)
DONE        answerdate - Answer time of call (UNIX-style integer timestamp)
DONE *      enddate - End time of call (UNIX-style integer timestamp)
*      duration - Total time in system, in seconds
DONE *      billsec - Total time call is up, in seconds
*[2]   disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
       amaflags - What flags to use: BILL, IGNORE etc, specified on a per
       channel basis like accountcode.
DONE *[3]   accountcode - CDR account number to use: account
       uniqueid - Unique channel identifier
       userfield - CDR user-defined field
       cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
FILLED_IN *[4]   charged_party - Service number to be billed
       upstream_currency - Wholesale currency from upstream
*[5]   upstream_price - Wholesale price from upstream
       upstream_rateplanid - Upstream rate plan ID
       rated_price - Rated (or re-rated) price
       distance - km (need units field?)
       islocal - Local - 1, Non Local = 0
*[6]   calltypenum - Type of call - see FS::cdr_calltype
       description - Description (cdr_type 7&8 only) (used for
       cust_bill_pkg.itemdesc)
       quantity - Number of items (cdr_type 7&8 only)
DONE       carrierid - Upstream Carrier ID (see FS::cdr_carrier)
       upstream_rateid - Upstream Rate ID
       svcnum - Link to customer service (see FS::cust_svc)
       freesidestatus - NULL, done (or something)

[1] Auto-populated from startdate if not present
[2] Package options available to ignore calls without a specific disposition
[3] When using 'cdr-charged_party-accountcode' config
[4] Auto-populated from src (normal calls) or dst (toll free calls) if not present
[5] When using 'upstream_simple' rating method.
[6] Set to usage class classnum when using pre-rated CDRs and usage class-based
    taxation (local/intrastate/interstate/international)

