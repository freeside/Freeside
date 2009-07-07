package FS::cdr::netcentrex;

use strict;
use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

#close enough http://wiki.freeswitch.org/wiki/Hangup_causes
#my %disposition = (
#  16 => 'ANSWERED',
#  17 => 'BUSY',
#  18 => 'NO USER RESPONSE',
#  19 => 'NO ANSWER',
#  156 => '??' #???
#);

%info = (
  'name'          => 'NetCentrex',
  'weight'        => 150,
  'type'          => 'csv',
  'sep_char'      => ';',
  'import_fields' => [
    '', #00 SU Identifier
    '', #01 SU IP Address
    '', #02 Conference ID
    '', #03 Call ID
    '', #04 Leg number (all 0)
    _cdr_date_parser_maker('startdate'),  #05 Authorize timestamp
    _cdr_date_parser_maker('answerdate'), #06 Start timestamp
    sub { my( $cdr, $duration ) = @_; #07 Duration
          $cdr->duration($duration);
          $cdr->billsec( $duration);
        },
    _e164_parser_maker('src',      'charged_party'),                 #08 Caller
    _e164_parser_maker('dcontext', 'dst', 'norewrite_pivotonly'=>1) ,#09 Callee
    'channel', #10 Source IP
    'dstchannel', #11 Destination IP
    'userfield', #12 selector Tag
    '', #13 *service Tag
    '', #14 *announcement Tag
    '', #15 *route Table Tag
    '', #16 vTrunkGroup Tag
    '', #17 vTrunk Tag XXX ? another userfield?
    '', #18 *termination Tag
    '', #19 *location group Tag
    '', #20 *GK Originating IP
    '', #21 *GK Terminating IP
    '', #22 *GK Originating Domain
    '', #23 *GK Terminating Domain
    '', #24 Malicious Call (all 0)
    '', #25 Service (all 0)
    'disposition', #26 Termination Cause 16/17/18/156
    '', #27 Simulation Call (all 0) supposedly don't bill 1
    '', #28 Type (all C)
    _cdr_date_parser_maker('enddate'), #29 ReleaseTimeStamp
        #seems empty from here in sampes...
    '', #30
    '', #31
    '', #32
    '', #33
    '', #34
    '', #35
    '', #36
    '', #37
    '', #38
    '', #39
    '', #40
    '', #41
    '', #42
    '', #43
    '', #44
    '', #45
    '', #46
    '', #47
    '', #48
    '', #49
    '', #50

        # * empty
  ],

);

sub _e164_parser_maker {
  my( $field, $pivot_field, %opt ) = @_;
  return sub {
    my( $cdr, $e164 ) = @_;
    my( $pivot, $number ) = _e164_parse($e164);
    if ( $opt{'norewrite_pivotonly'} && ! $pivot ) { 
      $cdr->$pivot_field( $number );
    } else {
      $cdr->$field( $number );
      $cdr->$pivot_field( $pivot );
    }
  };
}

sub _e164_parse {
  my $e164 = shift;

  $e164 =~ s/^e164://;

  my ($pivot, $number);
  if ( $e164 =~ /^O(\d+)$/ ) {
    $pivot = ''; #?
    $number = $1;
  } elsif ( $e164 =~ /^000000(\d+)$/ ) {
    $pivot = '';
    $number = $1;
  } elsif ( $e164 =~ /^(1\d{5})(\d+)$/ ) {
    $pivot = $1;
    $number = $2;
  } else {
    $pivot = '';
    $number = $e164; #unparsable...
  }

  ( $pivot, $number );
}

1;

=pod

       calldate - Call timestamp (SQL timestamp)
       clid - Caller*ID with text
                                          src - Caller*ID number / Source number
                                          dst - Destination extension
       dcontext - Destination context
                                          channel - Channel used
                                          dstchannel - Destination channel if appropriate
       lastapp - Last application if appropriate
       lastdata - Last application data
                                          startdate - Start of call (UNIX-style integer timestamp)
                                          answerdate - Answer time of call (UNIX-style integer timestamp)
                                          enddate - End time of call (UNIX-style integer timestamp)
       duration - Total time in system, in seconds
                                          billsec - Total time call is up, in seconds
                                          disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
       amaflags - What flags to use: BILL, IGNORE etc, specified on a per
       channel basis like accountcode.
       accountcode - CDR account number to use: account
       uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)
                                          userfield - CDR user-defined field
       cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
       charged_party - Service number to be billed
       upstream_currency - Wholesale currency from upstream
       upstream_price - Wholesale price from upstream
       upstream_rateplanid - Upstream rate plan ID
       rated_price - Rated (or re-rated) price
       distance - km (need units field?)
       islocal - Local - 1, Non Local = 0
       calltypenum - Type of call - see FS::cdr_calltype
       description - Description (cdr_type 7&8 only) (used for
       cust_bill_pkg.itemdesc)
       quantity - Number of items (cdr_type 7&8 only)
       carrierid - Upstream Carrier ID (see FS::cdr_carrier)
       upstream_rateid - Upstream Rate ID
       svcnum - Link to customer service (see FS::cust_svc)
       freesidestatus - NULL, done (or something)
       cdrbatch

No. Field         Type/Length Format / Remarks              Description                          Example
00  SU Identifier String      This field is never empty.    SU Identifier (as defined by su-     su01
                  <= 16 chars                               core.ini/[SU]/SUInstance key at SU
                                                                                                 192.168.121.1
                                                            initialization).
                                                            By default, the SUInstance is set to
                                                            a string that represents the SU
                                                            private IP address.
01  SU IP address String      ipv4:xx.xx.xx.xx<:port>       SU IP address (and ASM port) as      ipv4:213.56.136.29: 2518
                  <= 26 chars                               provided by su-
                              This field is never empty.
                                                            crouting.ini/[crRouting]/localASMa
                                                            ddress key.
02  Conference ID String      When [CDR_FIELDS]             Unique call session identifier       Advised format
                  <= 64 chars ReadlIDFormat is set to 1 in  provided by the SU, as received in   (ReadlIDFormat=1):
                              ncx-cdr-wrapper.ini (advised  call initiation message (H.225       910a4b12 cd67d93f
                              format):                      conferenceID field in Setup or       4300abd2 cc10a0a0
                                                            ARQ).
                              4x4 bytes as an hexadecimal                                        RealIDFormat=0:
                              string; double words are
                                                                                                 12.123.54.125.67.235.255.2
                              space-separated
                                                                                                 31.9.12.4.3.7.19.245.65
                              When [CDR_FIELDS]
                              ReadlIDFormat is set to 0 in
                              ncx-cdr-wrapper.ini:
                              16xdecimal notation of a 1-
                              byte number (0..255), dot-
                              separated.
                              This field is never empty.
03  Call ID       String      When [CDR_FIELDS]             Call identifier provided by the ASM  Advised format
                  <= 64 chars ReadlIDFormat is set to 1 in  in the SU (it can be the CallID or   (ReadlIDFormat=1):
                              ncx-cdr-wrapper.ini (advised  the RealCallID according to what is  910a4b12 cd67d93f
                              format):                      set in the ncx-cdr-wrapper.ini       4300abd2 cc10a0a0
                                                            UseRealCallID field). It is received
                              4x4 bytes as an hexadecimal                                        RealIDFormat=0:
                                                            in call initiation message (H.225
                              string; double words are
                                                            callID field in Setup or ARQ).       12.123.54.125.67.235.255.2
                              space-separated
                                                                                                 31.9.12.4.3.7.19.245.65
                              When [CDR_FIELDS]
                              ReadlIDFormat is set to 0 in
                              ncx-cdr-wrapper.ini:
                              16xdecimal notation of a 1-
                              byte number (0..255), dot-
                              separated.
                              This field may be empty if no
                              H.225 callID is present in
                              ARQ.
04  Leg number    Integer     Always set to 0 when the call Call attempt index, starting at 0.   0
                  ~ 1 char    is not deflected.             Incremented whenever a call leg
                                                            to a new destination is created.
                              This field is never empty.
                                                            A single call without any call
                                                            forward service will only have 1
                                                            CDR line, whose Leg number is set
                                                            to 0.
                                                            If a call is redirected (on
                                                            CFU/CFB/CNFR), it will generate a
                                                            second CDR line, leg number 1.
                                                            The leg number is then
                                                            incremented on each subsequent
                                                            redirection.

05 Authorize       Long        It can have two formats as       Authorize date and time of the call    1039189431
   timestamp       10 chars    given in the ncx-cdr-            leg => enable to have a date and
                               wrapper.ini by the               time if a call is not connected.
                               TimestampFormat field.           UTC.
                               If TimestampFormat is set to     This is the ARQ or SETUP or
                               0, the result string             INVITE reception timestamp for
                               corresponds to the "epoch"       the first call leg. For next tickets,
                               time, the number of elapsed      this is the call deflection processing
                               seconds since 1970/01/01         start time. Thus, this value may
                               00:00:00 (UTC)                   vary in tickets related to a
                                                                complete call.
                               If TimestampFormat is set to
                               1, the result string is 20 chars
                               in length (format: YYYY-MM-
                               DD HH:MM:SS)
                               NOTE: if you choose
                               TimestampFormat = 0 you
                               can have the tenth of second
                               (UseTenthOfSecond = 1) or
                               the micro second
                               (UseMicroSecond = 1)
                               NOTE: you can hide
                               timestamp equal to 0 (or
                               1970/01/01 00:00:00) with
                               the key HideNullTimestamp
                               set to 1.
                               This field is never empty.
06 Start timestamp Long        It can have two formats as       Starting date and time of the call     1039189431
                   10 chars    given in the ncx-cdr-            leg. UTC.
                               wrapper.ini by the
                                                                This is the CONNECT or OK (after
                               TimestampFormat field.
                                                                INVITE) reception timestamp. It is
                               If TimestampFormat is set to     set to the same value for all tickets
                               0, the result string             related to a call.
                               corresponds to the "epoch"
                               time, the number of elapsed
                               seconds since 1970/01/01
                               00:00:00 (UTC)
                               If TimestampFormat is set to
                               1, the result string is 20 chars
                               in length (format: YYYY-MM-
                               DD HH:MM:SS)
                               0 (or 1970/01/01 00:00:00)
                               means the connection was not
                               established for this call leg.
                               NOTE: if you choose
                               TimestampFormat = 0 you
                               can have the tenth of second
                               (UseTenthOfSecond = 1) or
                               the micro second
                               (UseMicroSecond = 1)
                               NOTE: you can hide
                               timestamp equal to 0 (or
                               1970/01/01 00:00:00) with
                               the key HideNullTimestamp
                               set to 1.
                               This field may be empty if the
                               call is not connected.
07 Duration        Long        In seconds (0 means the          Duration of the call leg (in           6
                   <= 10 chars connection was not               seconds), after the connection was
                               established for this call leg).  established.
                               NOTE: you can have the tenth     Set to 0 for SIP NOTIFICATION
                               of second (UseTenthOfSecond      and SIP MESSAGE reports.
                               = 1) or the micro second
                               (UseMicroSecond = 1)
                               This field is never empty.
08 Caller         String            e164:[number] or h323:[alias]  Main Source Alias in pivot format     e164:0010033575
                                    or email:[alias]               (provided by the ASM)
                  <= 128 chars
                                    This field may be empty if the If pivot format cannot be
                                    Caller pivot alias cannot be   computed then the main source
                                    computed.                      alias is presented in originating
                                                                   format and the "O" char is inserted
                                    See Use Cases section for
                                                                   at the beginning of the alias or
                                    possible cases.
                                                                   number.
                                                                   NOTE: the phone-context and
                                                                   trunk-context are set if present.
09 Callee         String            e164:[number] or h323:[alias]  E.164 Called Party Number alias or    e164:0010033762
                                    or email:[alias]               H323 destination ID in pivot
                  <= 128 chars
                                                                   format (provided by the ASM)
                                    This field may be empty if the
                                    Callee pivot alias cannot be   If pivot format cannot be
                                    computed.                      computed then the originating
                                                                   format is presented and the "O"
                                                                   char is inserted at the beginning of
                                                                   the alias or number.
                                                                   NOTE: the phone-context and
                                                                   trunk-context are set if present.
10 Source IP      String            ipv4:xx.xx.xx.xx<:port>        If ncx-cdr-wrapper.ini/useFullIP =    ipv4:192.168.1.2:34123
                                                                   0:
                  <= 26 chars       This field may be empty if the
                                    Source IP cannot be retrieved  Source IP address of the caller, as
                                    in IP message mode.            used for IP filtering (thus, may be
                                                                   either Packet IP address or
                                                                   CallSignalAddress, depending on
                                                                   su-
                                                                   crouting.ini/[defaultH323Parameter
                                                                   s]/ipFiltering key
                                                                   It can also be changed by the
                                                                   selector "extended actions"
                                                                   parameter. See "selector extended
                                                                   actions" dedicated documentation
                                                                   for further information.
                                                                   If ncx-cdr-wrapper.ini/useFullIP =
                                                                   1:
                                                                   Source IP packet address for the
                                                                   call leg
11 Destination IP String            ipv4:xx.xx.xx.xx<:port>        If ncx-cdr-wrapper.ini/useFullIP =    ipv4:213.56.162.17
                                                                   0:
                  <= 26 chars       This field may be empty if
                                    destination IP cannot be       Destination IP signaling address
                                    resolved.                      for the call leg
                                                                   If ncx-cdr-wrapper.ini/useFullIP =
                                                                   1:
                                                                   Destination IP packet address for
                                                                   the call leg
                                                                   NOTE: Can be different from the
                                                                   signaling address when routing
                                                                   through a proxy group. This field
                                                                   refers to the proxy IP address.
                                                                   Otherwise IP signaling address and
                                                                   IP packet address are the same.
12 selector Tag   String            This field is empty for non    Extensible tag. See extension tag     in=33231412345,vp=165,si
                  <= 199 chars      Business Services managed      format below.                         =123 tz=Europe/Berlin,
                                    sources and for Sites with no
                                                                   Selector Tag placed on the selector
                                    PSTN ranges allocated.
                                                                   for this call
                                                                   See [ref: 2] and [ref: 3] for further
                                                                         2            2
                                                                   information.
13 service Tag    Full alphanumeric This field is empty for now.   Service Tag placed on the selector
                  string                                           or on the vTrunkGroup for this call.
                                                                   See [ref: 2] and [ref: 3] for further
                                                                           2
                                                                   information.
14 announcement Full alphanumeric This field is empty for now. Announcement Tag placed on the
   Tag          string                                         selector, routeTable or
                                                               vTrunkGroup for this call.
                                                               See [ref: 2]and [ref: 3] for further
                                                                               2
                                                               information.
15 route Table Tag Full alphanumeric This field is empty for now.    Route table Tag placed on the
                   string                                            route table for this call.
                                                                     See [ref: 2] and [ref: 3] for further
                                                                          2             2
                                                                     information.
16 vTrunkGroup     Full alphanumeric This field is empty for now.    vTrunkGroupTag placed on the
   Tag             string                                            vTrunkGroup for this call.
                                                                     See [ref: 2] and [ref: 3] for further
                                                                            2
                                                                     information.
17 vTrunk Tag      String            This field is empty for non     Extensible tag. See extension tag     in=33156341289,vp=4232,s
                   <= 199 chars      Business Services managed       format below.                         i=132,tz=Europe/Paris
                                     destinations and for Sites with
                                                                     vTrunk Tag placed on the vTrunk
                                     no PSTN ranges allocated.
                                                                     for this call.
                                                                     See [ref: 2] and [ref: 3] for further
                                                                              2           2
                                                                     information.
18 termination Tag Full alphanumeric This field is empty for now.    Termination Tag placed on the
                   string                                            Termination for this call.
                                                                     See [ref: 2] and [ref: 3] for further
                                                                                2           2
                                                                     information.
19 location group  Full alphanumeric This field is empty for now.    location group Tag placed on the
   Tag             string                                            selector for this call.
                                                                     See [ref: 2] and [ref: 3] for further
                                                                                  2           2
                                                                     information.
20 GK Originating  Full alphanumeric This field is empty for now.    Parameter provided by the ASM in
   IP              string                                            the SU (reserved for future usage).
21 GK Terminating  Full alphanumeric This field is empty for now.    Parameter provided by the ASM in
   IP              string                                            the SU (reserved for future usage).
22 GK Originating  Full alphanumeric This field is empty for now.    Parameter provided by the ASM in
   Domain          string                                            the SU (reserved for future usage).
23 GK Terminating  Full alphanumeric This field is empty for now.    Parameter provided by the ASM in
   Domain          string                                            the SU (reserved for future usage).
24 Malicious Call  Boolean           0/1                             Indicate if a call is malicious or    0
                                                                     not. All calls to a specific called
                   1 char
                                                                     party will be tagged as malicious
                                                                     when the malicious feature has
                                                                     been activated.
25 Service         Long              0..31                           Bit mask for activated services for   6: at least one
                   <= 3 chars                                        this call.                            TECHNOLOGY and one
                                     This field is never empty.
                                                                                                           REMOVE service objects
                                                                     This is a combination between the
                                                                                                           have been used during
                                                                     following values:
                                                                                                           routing process
                                                                     1: if at least one CLIR service
                                                                                                           10: at least one BASIC-
                                                                     object has been used during
                                                                                                           XACTION and one REMOVE
                                                                     routing process
                                                                                                           service objects have been
                                                                     2: if at least one REMOVE service     used during routing process
                                                                     object has been used during
                                                                     routing process
                                                                     4: if at least one TECHNOLOGY
                                                                     service object has been used
                                                                     during routing process
                                                                     8: if at least one BASIC-XACTION
                                                                     service object has been used
                                                                     during routing process
                                                                     16: if at least one SUBSTITUTION
                                                                     service object has been used
                                                                     during routing process
                                                                     This is independent from the su-
                                                                     crouting.ini configuration file and
                                                                     in particular from the SPE
                                                                     activation.
26 Termination     Long              Causes in the range [1-127]       Cause of the call termination.      16
   Cause           <= 3 chars        are standard Q.850 causes
                                     Causes >= 128 are specific
                                     Comverse extension causes.
                                     See [ref. 5] for possible values
                                     and meanings.
                                     This field is never empty.
27 Simulation Call Boolean           0/1                               Indicates if a call is a simulation 0
                   1 char                                              call or not.
                                     This field is never empty.
                                                                       SIMULATION CALLS MUST NOT BE
                                                                       BILLED.
                                                                       Simulation calls can only be
                                                                       generated through the Telnet
                                                                       interface (tests and diagnostic
                                                                       only).
28 Type            One character     Optional field depending on       Type of CDR:                        C
                                     the UseType entry in ncx-cdr-
                   1 char                                              - Call ('C'): for INVITE and SETUP
                                     wrapper.ini. If set to 1, a
                                     value in this field will be       - Notification ('N') for SIP
                                     always printed: 'C' by default.   NOTIFICATION
                                     'C', 'N' or 'M'.                  - Message ('M') for SIP MESSAGE
                                     This field is never empty.
29 ReleaseTimeSta  Long              Optional field depending of       Release date of the leg.            1039189431
   mp              10 chars          the UseReleaseTimeStamp
                                     entry in ncx-cdr-wrapper.ini.
                                     It can have two formats as
                                     given in the ncx-cdr-
                                     wrapper.ini by the
                                     TimestampFormat field.
                                     If TimestampFormat is set to
                                     0, the result string
                                     corresponds to the "epoch"
                                     time, the number of elapsed
                                     seconds since 1970/01/01
                                     00:00:00 (UTC)
                                     If TimestampFormat is set to
                                     1, the result string is 20 chars
                                     in length (format: YYYY-MM-
                                     DD HH:MM:SS)
                                     NOTE: if you choose
                                     TimestampFormat = 0 you
                                     can have the tenth of second
                                     (UseTenthOfSecond = 1) or
                                     the micro second
                                     (UseMicroSecond = 1)
                                     NOTE: you can hide
                                     timestamp equal to 0 (or
                                     1970/01/01 00:00:00) with
                                     the key HideNullTimestamp
                                     set to 1.
                                     This field is empty when no
                                     CRR message is received and
                                     therefore it will be empty for
                                     the CDR describing presence
                                     message (SIP NOTIFY and SIP
                                     MESSAGE). It is also empty
                                     when the CDR is closed by the
                                     AMU (e.g. if the SU is
                                     detected as DOWN).
                                     In all other cases, this field is
                                     never empty
30 cgIdentity Tag  Full alphanumeric Optional: this field is filled if Extensible tag for Calling Party.   pu=33231345123,pr=23
                   string            usecgidentitytag is set to 1 in   See extension tag format below.
                   <= 132 chars      ncx-cdr-wrapper.ini.
                                     This field is empty for non
                                     Business Services/class V
                                     managed sources.
                                     The content of this field differs
                                     between BS and MyCall
                                     solutions.
31 cdIdentity Tag Full alphanumeric Optional: this field is filled if Extensible tag for Called Party. See pr=1111,bi=ADMIN
                  string            usecdidentitytag is set to 1 in   extension tag format below.
                  <= 132 chars      ncx-cdr-wrapper.ini
                                    This field is empty for non
                                    Business Services/class V
                                    managed destinations.
                                    The content of this field differs
                                    between BS and MyCall
                                    solutions.
32 Originating    String            Optional: this field is filled if E.164 Main Source alias or H323      e164:0010033575
   Caller         <= 128 chars      useoriginatingcaller is set to 1  source ID in originating format (as
                                    in ncx-cdr-wrapper.ini            received from the network)
                                    e164:[number] or h323:[alias]     The Main Source alias is computed
                                    or email:[alias]                  according to su-core.ini
                                                                      configuration.
                                                                      NOTE: the phone-context and
                                                                      trunk-context are set if present.
33 Originating    String            Optional: this field is filled if E.164 Main Destination alias or      e164:0010033762
   Callee         <= 128 chars      useoriginatingcallee is set to 1  H323 destination ID in originating
                                    in ncx-cdr-wrapper.ini            format (as received from the
                                                                      network)
                                    e164:[number] or h323:[alias]
                                    or email:[alias]                  The Main Destination alias is
                                                                      computed according to su-core.ini
                                                                      configuration.
                                                                      NOTE: the phone-context and
                                                                      trunk-context are set if present.
34 Terminating    String            Optional: this field is filled if E.164 Calling Party Number alias or  e164:0010033575
   Caller         <= 128 chars      useterminatingcaller is set to 1  H323 source ID in terminating
                                    in ncx-cdr-wrapper.ini            format (as provided to the
                                                                      network).
                                    e164:[number] or h323:[alias]
                                    or email:[alias]                  NOTE: the phone-context and
                                                                      trunk-context are set if present.
35 Terminating    String            Optional: this field is filled if E.164 Called Party Number alias or   e164:0010033762
   Callee         <= 128 chars      useterminatingcallee is set to    H323 destination ID in terminating
                                    1 in ncx-cdr-wrapper.ini.         format (as provided to the
                                                                      network).
                                    e164:[number] or h323:[alias]
                                    or email:[alias]                  NOTE: the phone-context and
                                                                      trunk-context are set if present.
                                    This field may be empty if no
                                    terminating destination aliases
                                    can be computed by the CRE
                                    (missing vtrunk transformation
                                    or unable to found a vtrunk
                                    for whatever routing reason),
                                    or if the pivot to terminating
                                    destination alias
                                    transformation leads to an
                                    empty alias.
36 Network          Long        Optional: this field is filled if  For H.323 the network timestamp      1039189431
   Timestamp        10 chars    usenetworkcompletiontimesta        is measured at the first Progress or
                                mp is set to 1 in ncx-cdr-         ALERT or CONNECT received by
                                wrapper.ini.                       the CCS for direct call.
                                                                   For redirected call, the network
                                It can have two formats as
                                                                   timestamp is measured by the
                                given in the ncx-cdr-
                                                                   CCS at the redirection decision
                                wrapper.ini by the
                                                                   point,
                                TimestampFormat field.
                                                                   NOTE: For H.323 calls, the tcp-ack
                                If TimestampFormat is set to
                                                                   of the outgoing TCP connection is
                                0, the result string
                                                                   not considered in the measure of
                                corresponds to the "epoch"
                                                                   network timestamp
                                time, the number of elapsed
                                seconds since 1970/01/01           For SIP the network timestamp is
                                00:00:00 (UTC)                     measured at the first SESSION
                                                                   PROGRESS or RINGING or OK
                                If TimestampFormat is set to
                                                                   received by the CCS for direct call.
                                1, the result string is 20 chars
                                in length (format: YYYY-MM-        The network timestamp is
                                DD HH:MM:SS)                       measured at the redirection
                                                                   decision point for redirected call.
                                NOTE: if you choose
                                TimestampFormat = 0 you
                                can have the tenth of second
                                (UseTenthOfSecond = 1) or
                                the micro second
                                (UseMicroSecond = 1)
                                NOTE: you can hide
                                timestamp equal to 0 (or
                                1970/01/01 00:00:00) with
                                the key HideNullTimestamp
                                set to 1.
                                This field may be empty if the
                                callee does not answer.
37 Targeted         Integer     Optional: this field is filled if  Provides information on the          12
   adaptor                      UseTargetedAdaptors is set to      adaptor that has been used: "1"
                    <= 2 chars
                                1 in ncx-cdr-wrapper.ini.          for adaptor1, "2" for adaptor2 and
                                                                   "12" for adaptor1 and adaptor2
                                "1", "2" or "12"
                                                                   See the amu-core.ini file section
                                                                   for further details on adaptors
                                                                   definition.
38 Adaptor1 errors  String      Optional: this field is filled if  Report errors on adaptor1 at the     cra,crr
                                UseAdaptor1Errors is set to 1      adaptor API level.
                    <= 15 chars
                                in ncx-cdr-wrapper.ini.
                                "nca" (error on the new call
                                authorize)
                                "cra" (error on the call re-
                                authorize)
                                "ncr" (error on the new call
                                report)
                                "crr" (error on the call release
                                report)
                                When several errors occurred,
                                comma separated notation will
                                be used.
                                Empty when no error has
                                been detected.
39 Source signaling String      Optional: this field is filled in  Source IP signaling address for the  ipv4:192.168.1.2:34123
   IP                           only if useFullIP is set to 1 in   call leg.
                    <= 26 chars
                                the ncx-cdr-wrapper.ini file.
                                                                   It can be changed by the selector
                                ipv4:xx.xx.xx.xx<:port>            "extended actions" parameter. See
                                                                   "selector extended actions"
                                This field may be empty if the
                                                                   dedicated documentation for
                                Source IP cannot be retrieved
                                                                   further information.
                                in IP message mode.
40 Destination      String      Optional: this fields is filled in Destination IP signaling address     ipv4:213.56.162.17
   signaling IP                 only if useFullIP is set to 1 in   for the call leg
                    <= 26 chars
                                ncx-cdr-wrapper.ini file.
                                ipv4:xx.xx.xx.xx<:port>, can
                                be empty if destination IP
                                cannot be resolved.
41 Source point      Unsigned integer  Optional: this field is filled in   SS7 point code, node identifier 1234
   code                                only if usePC is set to 1 in the
                     <= 5 chars
                                       ncx-cdr-wrapper.ini file.
                                       SIP: FROM header [TG-TEL]:
                                       PC is Encoded in the trunk-
                                       group part of a "tel" URI
                                       extension (see also RFC
                                       3966).
                                       H.323: H.225/circuitInfo:
                                       Encoded in an
                                       sourceCircuitID.cic.pointCode.
42 Destination point Unsigned integer  Optional: this field is filled in   SS7 point code, node identifier 1234
   code                                only if usePC is set to 1 in the
                     <= 5 chars
                                       ncx-cdr-wrapper.ini file.
                                       SIP: TO header [TG-TEL]: PC
                                       is encoded in the trunk-group
                                       part of a "tel" URI extension
                                       (see also RFC 3966).
                                       H.323: H.225/circuitInfo:
                                       Encoded in a
                                       destinationCircuitID.cic.pointC
                                       ode.
43 Origination tag   Full alphanumeric Optional: this field is filled in   Origination tag placed on the   crr=...,poi=...
                     string            only if useOriginationTag is        origination for this call.
                                       set to 1 in the ncx-cdr-
                                       wrapper.ini file.
44 Proxy group tag   Full alphanumeric Optional: this field is filled in   Proxy group Tag placed on the
                     string            only if useProxyGroupTag is         proxy group for this call.
                                       set to 1 in the ncx-cdr-
                                       wrapper.ini file.
                                       This field is empty for now.
45 Advice of Charge  String            Optional: this field only is filled AOC received.                   rend=10.2,unit=EURO
                                       in if UseAoc is set to 1 in ncx-
                     <= 50 chars       cdr-wrapper.ini file.               Available with CCS 3.8.4.
                                       This field may be empty if
                                       AOC service is not used or if
                                       no AOC value is available.
                                       <aocType>=<amount>,unit=
                                       <string> with:
                                       1. <aocType> (max length:
                                       7 chars):
                                       Received AOC-D: 'rduring'
                                       Received AOC-E, 'rend'
                                       Other AOC types are not yet
                                       supported by the su-core and
                                       therefore are ignored.
                                       2. <amount> (max length:
                                       14 chars):
                                       The amount is decoded from
                                       the received AOC-D or AOC-E.
                                       This value is mandatory in an
                                       AOC.
                                       3. unit=<string> (max length:
                                       15 chars):
                                       The unit string is the decoded
                                       unit value in the received
                                       AOC-D or AOC-E. This value is
                                       mandatory in an AOC.
46 Routing Context String       Optional                          Routing context of the leg.          basic
                   <= 5 chars   3 possible values:                For IMS calls, routing context has
                                                                  the value "orig" or "term".
                                - basic                           Otherwise, it is set to "basic".
                                - orig
                                                                  Dependencies:
                                - term
                                                                  -            amu-core-4.8.0
                                                                  -            adaptor-generic-cdr-
                                                                    1.8.0
                                                                  -            ncx-cdr-wrapper-1.8.0
47 Originating     String       Optional: this field is filled if E164 Main Source alias or H323       e164:33762
   Original Caller <= 128 chars useoriginatingoriginalcaller is   source ID in originating format (as
                                set to 1 in ncx-cdr-              received from the network) of the
                                wrapper.ini.                      original caller.
                                e164:[number] or h323:[alias]     The main source alias is computed
                                or email:[alias]                  according to su-core.ini
                                                                  configuration.
                                                                  NOTE: the phone-context and
                                                                  trunk-context are set if present.
                                                                  Dependencies:
                                                                  -            amu-core-4.10.0
                                                                  -            adaptor-generic-cdr-
                                                                    1.10.0
                                                                  -            ncx-cdr-wrapper-1.10.0
48 Pivot Original  String       Optional: this field is filled if E164 Main Source alias or H323       E164:0010033762
   Caller          <= 128 chars usepivotoriginalcaller is set to  source ID in pivot format (as
                                1 in ncx-cdr-wrapper.ini.         received from the network) of the
                                                                  original caller
                                e164:[number] or h323:[alias]
                                or email:[alias]                  They are sent if present by SU if
                                                                  su-
                                                                  crouting.ini/[compatibility]/aliasRe
                                                                  porting is 5_0_0 or greater
                                                                  NOTE: the phone-context and
                                                                  trunk-context are set if present.
                                                                  Dependencies:
                                                                  -            amu-core-4.10.0
                                                                  -            adaptor-generic-cdr-
                                                                    1.10.0
                                                                  -            ncx-cdr-wrapper-1.10.0
49 Terminating     String       Optional: this field is filled if E164 Main Source alias or H323       E164:0010033762
   Original Caller <= 128 chars useterminatingoriginalcaller is   source ID in terminating format (as
                                set to 1 in ncx-cdr-              received from the network) of the
                                wrapper.ini.                      original caller.
                                e164:[number] or h323:[alias]     They are sent if present by SU if
                                or email:[alias]                  su-
                                                                  crouting.ini/[compatibility]/aliasRe
                                                                  porting is 5_0_0 or greater
                                                                  NOTE: the phone-context and
                                                                  trunk-context are set if present.
                                                                  Dependencies:
                                                                  -            amu-core-4.10.0
                                                                  -            adaptor-generic-cdr-
                                                                    1.10.0
                                                                  -            ncx-cdr-wrapper-1.10.0
50 Pivotclir Boolean Optional: this field is filled if Pivot CLIR calculated with caller  clir=0
                     UsePivotClir is set to 1 in ncx-  information.
             6 chars cdr-wrapper.ini.
                                                       Dependencies:
                     0 means that Calling Line
                     Identification is showed.         -           amu-core-4.12.0
                     1 means that Calling Line         -           adaptor-generic-cdr-
                     Identification is hidden.           1.12.0
                                                       -           ncx-cdr-wrapper-1.12.0

