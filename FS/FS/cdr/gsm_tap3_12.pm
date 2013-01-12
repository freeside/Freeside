package FS::cdr::gsm_tap3_12;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use Time::Local;
use Data::Dumper;

%info = (
  'name'          => 'GSM TAP3 release 12',
  'weight'        => 50,
  'type'          => 'asn.1',
  'import_fields' => [],
  'asn_format'    => {
    'spec'     => _asn_spec(),
    'macro'    => 'TransferBatch', #XXX & skip the Notification ones?
    'arrayref' => sub { shift->{'callEventDetails'}; },
    'map'      => {
                    'startdate'          => sub { my $callinfo = shift->{mobileOriginatedCall}{basicCallInformation};
                                                  my $timestamp = $callinfo->{callEventStartTimeStamp};
                                                  my $localTimeStamp = $timestamp->{localTimeStamp};
                                                  my $utcTimeOffsetCode = $timestamp->{utcTimeOffsetCode}; #XXX not handled, utcTimeOffsetInfo in header
                                                  $localTimeStamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/ or die "unparsable timestamp: $localTimeStamp\n"; #. Dumper($callinfo);
                                                  my($year, $mon, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
                                                  timelocal($sec, $min, $hour, $day, $mon-1, $year);
                                                },
                    'duration'           => sub { shift->{mobileOriginatedCall}{basicCallInformation}{totalCallEventDuration} },
                    'billsec'            => sub { shift->{mobileOriginatedCall}{basicCallInformation}{totalCallEventDuration} }, #same..
                    'src'                => sub { shift->{mobileOriginatedCall}{basicCallInformation}{chargeableSubscriber}{simChargeableSubscriber}{msisdn} },
                    'charged_party_imsi' => sub { shift->{mobileOriginatedCall}{basicCallInformation}{chargeableSubscriber}{simChargeableSubscriber}{imsi} },
                    'dst'                => sub { shift->{mobileOriginatedCall}{basicCallInformation}{destination}{calledNumber} }, #dialledDigits?
                    'carrierid'          => sub { shift->{mobileOriginatedCall}{locationInformation}{networkLocation}{recEntityCode} }, #XXX translate to recEntityId via info in header
                    'userfield'          => sub { shift->{mobileOriginatedCall}{operatorSpecInformation}[0] },
                    'servicecode'        => sub { shift->{mobileOriginatedCall}{basicServiceUsedList}[0]{basicService}{serviceCode}{teleServiceCode} },
                    'upstream_price'     => sub { sprintf('%.5f', shift->{mobileOriginatedCall}{basicServiceUsedList}[0]{chargeInformationList}[0]{chargeDetailList}[0]{charge} / 100000 ) }, #XXX numberOfDecimalPlaces in header
                    'calltypenum'        => sub { shift->{mobileOriginatedCall}{basicServiceUsedList}[0]{chargeInformationList}[0]{callTypeGroup}{callTypelevel1} },
                    'quantity'           => sub { shift->{mobileOriginatedCall}{basicServiceUsedList}[0]{chargeInformationList}[0]{chargedUnits} },
                    'quantity_able'      => sub { shift->{mobileOriginatedCall}{basicServiceUsedList}[0]{chargeInformationList}[0]{chargeableUnits} },
                  },
  },
);

#accepts qsearch parameters as a hash or list of name/value pairs, but not
#old-style qsearch('cdr', { field=>'value' })

use Date::Format;
sub tap3_12_export {
  my %qsearch = ();
  if ( ref($_[0]) eq 'HASH' ) {
    %qsearch = %{ $_[0] };
  } else {
    %qsearch = @_;
  }

  #if these get huge we might need to get a count and do a paged search
  my @cdrs = qsearch({ 'table'=>'cdr', %qsearch, 'order_by'=>'calldate ASC' });

  eval "use Convert::ASN1";
  die $@ if $@;

  my $asn = Convert::ASN1->new;
  $asn->prepare( _asn_spec() ) or die $asn->error;

  my $TransferBatch = $asn->find('TransferBatch') or die $asn->error;

  my %hash = _TransferBatch(); #static information etc.

  my $utcTimeOffset = '+0300'; #XXX local timezone at least

  my $now = time;

  ###
  # accountingInfo
  ###

  ###
  # batchControlInfo
  ###

  #optional
  $hash{batchControlInfo}->{fileCreationTimeStamp}   = { 'localTimeStamp' => time2str('%Y%m%d%H%M%S', $now),
                                                         'utcTimeOffset'  => $utcTimeOffset,
                                                       };
  #XXX what do these do?  do they need to be different from fileCreationTimeStamp?
  $hash{batchControlInfo}->{transferCutOffTimeStamp} = { 'localTimeStamp' => time2str('%Y%m%d%H%M%S', $now),
                                                         'utcTimeOffset'  => $utcTimeOffset,
                                                       };

  $hash{batchControlInfo}->{fileAvailableTimeStamp}  = { 'localTimeStamp' => time2str('%Y%m%d%H%M%S', $now),
                                                          'utcTimeOffset'  => $utcTimeOffset,
                                                        };

  #XXX
  $hash{batchControlInfo}->{sender} = 'MDGTM';
  $hash{batchControlInfo}->{recipient} = 'GNQHT';
  $hash{batchControlInfo}->{fileSequenceNumber} = '00178'; #XXX global?  per recipient?

  ###
  # networkInfo
  ###

  $hash{networkInfo}->{utcTimeOffsetInfo}[0]{utcTimeOffset} = $utcTimeOffset;

  #XXX recording entity IDs, referenced by recEntityCode
  #$hash->{networkInfo}->{recEntityInfo}[0]{recEntityId} = '340010100';
  #$hash->{networkInfo}->{recEntityInfo}[1]{recEntityId} = '240556000000';

  ###
  # auditControlInfo
  ###

  #mandatory
  $hash{auditControlInfo}->{callEventDetailsCount} = scalar(@cdrs);

  #these two are optional
  $hash{auditControlInfo}->{earliestCallTimeStamp} = { 'localTimeStamp' => time2str('%Y%m%d%H%M%S', $cdrs[0]->calldate_unix),
                                                       'utcTimeOffset'  => $utcTimeOffset,
                                                     };
  $hash{auditControlInfo}->{latestCallTimeStamp}   = { 'localTimeStamp' => time2str('%Y%m%d%H%M%S', $cdrs[-1]->calldate_unix),
                                                       'utcTimeOffset'  => $utcTimeOffset,
                                                     };

  #mandatory
  my $totalCharge = 0;
  $totalCharge += $_->rated_price foreach @cdrs;
  $hash{totalCharge} = sprintf('%.5f', $totalCharge);

  ###
  # callEventDetails
  ###

  #one of Mobile Originated Call, Mobile Terminated Call, Mobile Session, Messaging Event, Supplementary Service Event, Service Centre Usage, GPRS Call, Content Transaction or Location Service
  # Each occurrence must have no more than one of these present

  $hash{callEventDetails} = [
    map {
          { #either tele or bearer service usage originated by the mobile subscription (others?)
            'mobileOriginatedCall' => {

              #identifies the Network Location, which includes the MSC responsible for handling the call and, where appropriate, the Geographical Location of the mobile
              'locationInformation' => {
                                         'networkLocation' => {
                                                                'recEntityCode' => $_->carrierid, #XXX Recording Entity (per 2.5, from "Reference Tables")
                                                              }
                                       },

              #Operator Specific Information: beyond the scope of TAP and has been bilaterally agreed
              'operatorSpecInformation' => [
                                             $_->userfield, ##'|Seq: 178 Loc: 1|'
                                           ],

              #The type of service used together with all related charging information
              'basicServiceUsedList' => [
                                          {
                                            #identifies the actual Basic Service used
                                            'basicService' => {
                                                                #one of Teleservice Code or Bearer Service Code as determined by the service type used
                                                                'serviceCode' => {
                                                                                   #XXX
                                                                                   #00 All teleservices
                                                                                   #10 All Speech transmission services
                                                                                   #11 Telephony
                                                                                   #12 Emergency calls
                                                                                   #20 All SMS Services
                                                                                   #21 Short Message MT/PP
                                                                                   #22 Short Message MO/PP
                                                                                   #60 All Fax Services
                                                                                   #61 Facsimile Group 3 & alternative speech
                                                                                   #62 Automatic Facsimile Group 3
                                                                                   #63 Automatic Facsimile Group 4
                                                                                   #70 All data teleservices (compound)
                                                                                   #80 All teleservices except SMS (compound)
                                                                                   #90 All voice group call services
                                                                                   #91 Voice group call
                                                                                   #92 Voice broadcast call
                                                                                   'teleServiceCode' => $_->servicecode, #'11'

                                                                                   #Bearer Service Code
                                                                                   # Must be present within group Service Code where the type of service used
                                                                                   #  was a bearer service. Must not be present when the type of service used
                                                                                   #  was a tele service and, therefore, Teleservice Code is present.
                                                                                   # Group Bearer Codes, identifiable by the description ‘All’, should only
                                                                                   #  be used where details of the specific services affected are not
                                                                                   #  available from the network.
                                                                                   #00 All Bearer Services
                                                                                   #20 All Data Circuit Asynchronous Services
                                                                                   #21 Duplex Asynch. 300bps data circuit
                                                                                   #22 Duplex Asynch. 1200bps data circuit
                                                                                   #23 Duplex Asynch. 1200/75bps data circuit
                                                                                   #24 Duplex Asynch. 2400bps data circuit
                                                                                   #25 Duplex Asynch. 4800bps data circuit
                                                                                   #26 Duplex Asynch. 9600bps data circuit
                                                                                   #27 General Data Circuit Asynchronous Service
                                                                                   #30 All Data Circuit Synchronous Services
                                                                                   #32 Duplex Synch. 1200bps data circuit
                                                                                   #34 Duplex Synch. 2400bps data circuit
                                                                                   #35 Duplex Synch. 4800bps data circuit
                                                                                   #36 Duplex Synch. 9600bps data circuit
                                                                                   #37 General Data Circuit Synchronous Service
                                                                                   #40 All Dedicated PAD Access Services
                                                                                   #41 Duplex Asynch. 300bps PAD access
                                                                                   #42 Duplex Asynch. 1200bps PAD access
                                                                                   #43 Duplex Asynch. 1200/75bps PAD access
                                                                                   #44 Duplex Asynch. 2400bps PAD access
                                                                                   #45 Duplex Asynch. 4800bps PAD access
                                                                                   #46 Duplex Asynch. 9600bps PAD access
                                                                                   #47 General PAD Access Service
                                                                                   #50 All Dedicated Packet Access Services
                                                                                   #54 Duplex Synch. 2400bps PAD access
                                                                                   #55 Duplex Synch. 4800bps PAD access
                                                                                   #56 Duplex Synch. 9600bps PAD access
                                                                                   #57 General Packet Access Service
                                                                                   #60 All Alternat Speech/Asynchronous Services
                                                                                   #70 All Alternate Speech/Synchronous Services
                                                                                   #80 All Speech followed by Data Asynchronous Services
                                                                                   #90 All Speech followed by Data Synchronous Services
                                                                                   #A0 All Data Circuit Asynchronous Services (compound)
                                                                                   #B0 All Data Circuit Synchronous Services (compound)
                                                                                   #C0 All Asynchronous Services (compound)
                                                                                 }
                                                                #conditionally also contain the following for UMTS: Transparency Indicator, Fixed Network User
                                                                # Rate, User Protocol Indicator, Guaranteed Bit Rate and Maximum Bit Rate
                                                              },

                                            #Charge information is provided for all chargeable elements except within Messaging Event and Mobile Session call events
                                            # must contain Charged Item and at least one occurrence of Charge Detail
                                            'chargeInformationList' => [
                                                                         {
                                                                           #XXX
                                                                           #mandatory
                                                                           # the charging principle applied and the unitisation of Chargeable Units.  It
                                                                           #  is not intended to identify the service used.
                                                                           #A: Call set up attempt
                                                                           #C: Content
                                                                           #D: Duration based charge
                                                                           #E: Event based charge
                                                                           #F: Fixed (one-off) charge
                                                                           #L: Calendar (for example daily usage charge)
                                                                           #V: Volume (outgoing) based charge
                                                                           #W: Volume (incoming) based charge
                                                                           #X: Volume (total volume) based charge
                                                                           #(?? fields to be used as a basis for the calculation of the correct Charge
                                                                           #  A: Chargeable Units (if present)
                                                                           #  D,V,W,X: Chargeable Units
                                                                           #  C: Depends on the content
                                                                           #  E: Not Applicable
                                                                           #  F: Not Applicable
                                                                           #  L: Call Event Start Timestamp)
                                                                           'chargedItem' => 'D',

                                                                           # the IOT used by the VPMN to price the call
                                                                           'callTypeGroup' => {

                                                                                                #The highest category call type in respect of the destination of the call
                                                                                                #0: Unknown/Not Applicable
                                                                                                #1: National
                                                                                                #2: International
                                                                                                #10: HGGSN/HP-GW
                                                                                                #11: VGGSN/VP-GW
                                                                                                #12: Other GGSN/Other P-GW
                                                                                                #100: WLAN
                                                                                                'callTypeLevel1' => $_->calltypenum,

                                                                                                #the sub category of Call Type Level 1
                                                                                                #0: Unknown/Not Applicable
                                                                                                #1: Mobile
                                                                                                #2: PSTN
                                                                                                #3: Non Geographic
                                                                                                #4: Premium Rate
                                                                                                #5: Satellite destination
                                                                                                #6: Forwarded call
                                                                                                #7: Non forwarded call
                                                                                                #10: Broadband
                                                                                                #11: Narrowband
                                                                                                #12: Conversational
                                                                                                #13: Streaming
                                                                                                #14: Interactive
                                                                                                #15: Background
                                                                                                'callTypeLevel2' => 0,

                                                                                                #the sub category of Call Type Level 2
                                                                                                'callTypeLevel3' => 0,
                                                                                              },

                                                                           #mandatory, at least one occurence must be present
                                                                           #A repeating group detailing the Charge and/or charge element
                                                                           # Note that, where a Charge has been levied, even where that Charge is zero,
                                                                           #  there must be one occurance, and only one, with a Charge Type of '00'
                                                                           'chargeDetailList' => [
                                                                                                   {
                                                                                                     #mandatory
                                                                                                     # after discounts have been deducted but before any tax is added
                                                                                                     'charge'          => $_->rated_price * 100000, #XXX numberOfDecimalPlaces 

                                                                                                     #mandatory
                                                                                                     # the type of charge represented
                                                                                                     #00: Total charge for Charge Information (the invoiceable value)
                                                                                                     #01: Airtime charge
                                                                                                     #02: reserved
                                                                                                     #03: Toll charge
                                                                                                     #04: Directory assistance
                                                                                                     #05–20: reserved
                                                                                                     #21: VPMN surcharge
                                                                                                     #50: Total charge for Charge Information according to the published IOT
                                                                                                     #  Note that the use of value 50 is only for use by bilateral agreement, use without
                                                                                                     #   bilateral agreement can be treated as per reserved values, that is ‘out of range’
                                                                                                     #69–99: reserved
                                                                                                     'chargeType'      => '00',

                                                                                                     #conditional
                                                                                                     # the number of units which are chargeable within the Charge Detail, this may not
                                                                                                     # correspond to the number of rounded units charged.
                                                                                                     # The item Charged Item defines what the units represent.
                                                                                                     'chargeableUnits' => $_->quantity_able,

                                                                                                     #optional
                                                                                                     # the rounded number of units which are actually charged for
                                                                                                     'chargedUnits'    => $_->quantity,
                                                                                                   }
                                                                                                 ],
                                                                           'exchangeRateCode' => 1, #from header
                                                                         }
                                                                       ]
                                          }
                                        ],

              #MO Basic Call Information provides the basic detail of who made the call and where to in respect of mobile originated traffic.
              'basicCallInformation' => {
                                          #mandatory
                                          # the identification of the chargeable subscriber.
                                          #  The group must contain either the IMSI or the MIN of the Chargeable Subscriber, but not both.
                                          'chargeableSubscriber' => {
                                                                      'simChargeableSubscriber' => {
                                                                                                     'msisdn' => $_->charged_party, #src
                                                                                                     'imsi'   => $_->charged_party_imsi,
                                                                                                   }
                                                                    },
                                          # the start of the call event
                                          'callEventStartTimeStamp' => {
                                                                         'localTimeStamp' => time2str('%Y%m%d%H%M%S', $_->startdate),
                                                                         'utcTimeOffsetCode' => 1
                                                                       },

                                          # the actual total duration of a call event as a number of seconds
                                          'totalCallEventDuration' => $_->duration,

                                          #conditional
                                          # the number dialled by the subscriber (Called Number)
                                          #  or the SMSC Address in case of SMS usage or in cases involving supplementary services
                                          #   such as call forwarding or transfer etc., the number to which the call is routed
                                          'destination' => {
                                                             #the international representation of the destination
                                                             'calledNumber' => $_->dst,

                                                             #the actual digits as dialled by the subscriber, i.e. unmodified, in establishing a call
                                                             # This will contain ‘+’ and ‘#’ where appropriate.
                                                             #'dialledDigits' => '322221350'
                                                           },
                                        }
            }
          };
        }
      @cdrs
  ];


  ###


  my $pdu = $TransferBatch->encode( \%hash );

  return $pdu;

}

sub _TransferBatch {
          'accountingInfo' => {
                                #mandatory
                                'localCurrency' => 'USD',
                                'currencyConversionInfo' => [
                                                              {
                                                                'numberOfDecimalPlaces' => 5,
                                                                'exchangeRate' => 152549, #???
                                                                'exchangeRateCode' => 1
                                                              }
                                                            ],
                                'tapDecimalPlaces' => 5,
                                #optional: may conditionally include taxation and discounting tables, and, optionally, TAP currency
                              },
          'batchControlInfo' => {
                                  #mandatory
                                  'specificationVersionNumber' => 3,
                                  'releaseVersionNumber' => 12, #11?

                                  #'sender' => 'MDGTM',
                                  #'recipient' => 'GNQHT',
                                  #'fileSequenceNumber' => '00178',

                                  #'transferCutOffTimeStamp' => {
                                  #                               'localTimeStamp' => '20121230050222',
                                  #                               'utcTimeOffset' => '+0300'
                                  #                             },
                                  #'fileAvailableTimeStamp' => {
                                  #                              'localTimeStamp' => '20121230035052',
                                  #                              'utcTimeOffset' => '+0100'
                                  #                            }

                                  #optional
                                  #'fileCreationTimeStamp' => {
                                  #                             'localTimeStamp' => '20121230050222',
                                  #                             'utcTimeOffset' => '+0300'
                                  #                           },

                                  #optional: file type indicator which will only be present where the file represents test data
                                  #optional: RAP File Sequence Number (used where the batch has previously been returned with a fatal error and is now being resubmitted) (not fileSequenceNumber?)

                                  #optional: beyond the scope of TAP and has been bilaterally agreed
                                  'operatorSpecInformation' => [
                                                                 '', # XXX '|File proc MTH LUXMA: 1285348027|' Operator Specific Information
                                                               ],
             

                                },

          #Network Information is a group of related information which pertains to the Sender PMN
          'networkInfo' => {
                             #must be present where Recording Entity Codes are present within the TAP file
                             'recEntityInfo' => [
                                                  {
                                                    'recEntityType' => 1, #MSC
                                                    #'recEntityId' => '340010100',
                                                    'recEntityCode' => 1
                                                  },
                                                  {
                                                    'recEntityType' => 2, #SMSC
                                                    #'recEntityId' => '240556000000',
                                                    'recEntityCode' => 2
                                                  },
                                                ],
                             #mandatory
                             'utcTimeOffsetInfo' => [
                                                      {
                                                        'utcTimeOffset' => '+0300',
                                                        'utcTimeOffsetCode' => 1
                                                      }
                                                    ]
                           },
          'auditControlInfo' => {
                                  #'callEventDetailsCount' => 4, #mandatory
                                  'totalTaxValue'         => 0, #mandatory
                                  'totalDiscountValue'    => 0, #mandatory
                                  #'totalCharge'           => 50474, #mandatory

                                  #these two are optional
                                  #'earliestCallTimeStamp' => {
                                  #                             'localTimeStamp' => '20121229102501',
                                  #                             'utcTimeOffset' => '+0300'
                                  #                           },
                                  #'latestCallTimeStamp'   => {
                                  #                             'localTimeStamp' => '20121229102807',
                                  #                             'utcTimeOffset' => '+0300'
                                  #                           }
                                },
}

sub _asn_spec {
  <<'END';
--
--
-- The following ASN.1 specification defines the abstract syntax for 
--
--        Data Record Format Version 03 
--                           Release 12
--
-- The specification is structured as follows:
--   (1) structure of the Tap batch
--   (2) definition of the individual Tap ‘records’ 
--   (3) Tap data items and groups of data items used within (2)
--   (4) Common, non-Tap data types
--   (5) Tap data items for content charging
--
-- It is mainly a translation from the logical structure
-- diagrams. Where appropriate, names used within the 
-- logical structure diagrams have been shortened.
-- For repeating data items the name as used within the logical
-- structure have been extended by adding ‘list’ or ‘table’
-- (in some instances).
--


-- TAP-0312  DEFINITIONS IMPLICIT TAGS  ::= 

-- BEGIN 

--
-- Structure of a Tap batch 
--

DataInterChange ::= CHOICE 
{
    transferBatch TransferBatch, 
    notification  Notification,
...
}

-- Batch Control Information must always, both logically and physically,
-- be the first group/item within Transfer Batch – this ensures that the
-- TAP release version can be readily identified.  Any new groups/items
-- required may be inserted at any point after Batch Control Information

TransferBatch ::= [APPLICATION 1] SEQUENCE
{
    batchControlInfo       BatchControlInfo            OPTIONAL, -- *m.m.
    accountingInfo         AccountingInfo              OPTIONAL,
    networkInfo            NetworkInfo                 OPTIONAL, -- *m.m.
    messageDescriptionInfo MessageDescriptionInfoList  OPTIONAL,
    callEventDetails       CallEventDetailList         OPTIONAL, -- *m.m.
    auditControlInfo       AuditControlInfo            OPTIONAL, -- *m.m.
...
}

Notification ::= [APPLICATION 2] SEQUENCE
{
    sender                     Sender                     OPTIONAL, -- *m.m.
    recipient               	 Recipient                  OPTIONAL, -- *m.m.
    fileSequenceNumber      	 FileSequenceNumber         OPTIONAL, -- *m.m.
    rapFileSequenceNumber   	 RapFileSequenceNumber      OPTIONAL,
    fileCreationTimeStamp   	 FileCreationTimeStamp      OPTIONAL,
    fileAvailableTimeStamp  	 FileAvailableTimeStamp     OPTIONAL, -- *m.m.
    transferCutOffTimeStamp 	 TransferCutOffTimeStamp    OPTIONAL, -- *m.m.
    specificationVersionNumber SpecificationVersionNumber OPTIONAL, -- *m.m.
    releaseVersionNumber    	 ReleaseVersionNumber       OPTIONAL, -- *m.m.
    fileTypeIndicator       	 FileTypeIndicator          OPTIONAL,
    operatorSpecInformation 	 OperatorSpecInfoList       OPTIONAL,
...
}

CallEventDetailList ::=  [APPLICATION 3] SEQUENCE OF CallEventDetail

CallEventDetail ::= CHOICE
{
    mobileOriginatedCall   MobileOriginatedCall,
    mobileTerminatedCall   MobileTerminatedCall,
    supplServiceEvent      SupplServiceEvent,
    serviceCentreUsage     ServiceCentreUsage,
    gprsCall               GprsCall,
    contentTransaction     ContentTransaction,
    locationService        LocationService,
    messagingEvent         MessagingEvent,
    mobileSession          MobileSession,
...
}

--
-- Structure of the individual Tap records
--

BatchControlInfo ::= [APPLICATION 4] SEQUENCE
{
    sender                 	 Sender				OPTIONAL, -- *m.m.
    recipient              	 Recipient				OPTIONAL, -- *m.m.
    fileSequenceNumber     	 FileSequenceNumber		OPTIONAL, -- *m.m.
    fileCreationTimeStamp  	 FileCreationTimeStamp		OPTIONAL,
    transferCutOffTimeStamp 	 TransferCutOffTimeStamp	OPTIONAL, -- *m.m.
    fileAvailableTimeStamp  	 FileAvailableTimeStamp		OPTIONAL, -- *m.m.
    specificationVersionNumber SpecificationVersionNumber	OPTIONAL, -- *m.m.
    releaseVersionNumber    	 ReleaseVersionNumber		OPTIONAL, -- *m.m.
    fileTypeIndicator       	 FileTypeIndicator		OPTIONAL,
    rapFileSequenceNumber   	 RapFileSequenceNumber		OPTIONAL,
    operatorSpecInformation 	 OperatorSpecInfoList		OPTIONAL,
...
}

AccountingInfo ::= [APPLICATION 5] SEQUENCE
{
    taxation                  TaxationList           OPTIONAL,
    discounting               DiscountingList        OPTIONAL,
    localCurrency             LocalCurrency          OPTIONAL, -- *m.m.
    tapCurrency               TapCurrency            OPTIONAL,
    currencyConversionInfo    CurrencyConversionList OPTIONAL,
    tapDecimalPlaces          TapDecimalPlaces       OPTIONAL, -- *m.m.
...
}

NetworkInfo ::= [APPLICATION 6] SEQUENCE
{
    utcTimeOffsetInfo         UtcTimeOffsetInfoList OPTIONAL, -- *m.m.
    recEntityInfo             RecEntityInfoList     OPTIONAL,
...
}

MessageDescriptionInfoList ::= [APPLICATION 8] SEQUENCE OF MessageDescriptionInformation

MobileOriginatedCall ::= [APPLICATION 9] SEQUENCE
{
    basicCallInformation    MoBasicCallInformation    OPTIONAL, -- *m.m.
    locationInformation     LocationInformation       OPTIONAL, -- *m.m.
    equipmentIdentifier     ImeiOrEsn                 OPTIONAL,
    basicServiceUsedList    BasicServiceUsedList      OPTIONAL, -- *m.m.
    supplServiceCode        SupplServiceCode          OPTIONAL,
    thirdPartyInformation   ThirdPartyInformation     OPTIONAL,
    camelServiceUsed        CamelServiceUsed          OPTIONAL,
    operatorSpecInformation OperatorSpecInfoList      OPTIONAL,
...
}    

MobileTerminatedCall ::= [APPLICATION 10] SEQUENCE
{
    basicCallInformation    MtBasicCallInformation    OPTIONAL, -- *m.m.
    locationInformation     LocationInformation       OPTIONAL, -- *m.m.
    equipmentIdentifier     ImeiOrEsn                 OPTIONAL,
    basicServiceUsedList    BasicServiceUsedList      OPTIONAL, -- *m.m.
    camelServiceUsed        CamelServiceUsed          OPTIONAL,
    operatorSpecInformation OperatorSpecInfoList      OPTIONAL,
...
}    


SupplServiceEvent ::= [APPLICATION 11] SEQUENCE
{
    chargeableSubscriber      ChargeableSubscriber    OPTIONAL, -- *m.m.
    rapFileSequenceNumber     RapFileSequenceNumber   OPTIONAL,
    locationInformation       LocationInformation     OPTIONAL, -- *m.m.
    equipmentIdentifier       ImeiOrEsn               OPTIONAL,
    supplServiceUsed          SupplServiceUsed        OPTIONAL, -- *m.m.
    operatorSpecInformation   OperatorSpecInfoList    OPTIONAL,
...
}


ServiceCentreUsage ::= [APPLICATION 12] SEQUENCE
{
    basicInformation          ScuBasicInformation     OPTIONAL, -- *m.m.
    rapFileSequenceNumber     RapFileSequenceNumber   OPTIONAL,
    servingNetwork            ServingNetwork          OPTIONAL,
    recEntityCode             RecEntityCode           OPTIONAL, -- *m.m.
    chargeInformation         ChargeInformation       OPTIONAL, -- *m.m.
    scuChargeType             ScuChargeType           OPTIONAL, -- *m.m.
    scuTimeStamps             ScuTimeStamps           OPTIONAL, -- *m.m.
    operatorSpecInformation   OperatorSpecInfoList    OPTIONAL,
...
}

GprsCall ::= [APPLICATION 14] SEQUENCE
{
    gprsBasicCallInformation  GprsBasicCallInformation  OPTIONAL, -- *m.m.
    gprsLocationInformation   GprsLocationInformation   OPTIONAL, -- *m.m.
    equipmentIdentifier       ImeiOrEsn                 OPTIONAL,
    gprsServiceUsed           GprsServiceUsed           OPTIONAL, -- *m.m.
    camelServiceUsed          CamelServiceUsed          OPTIONAL,
    operatorSpecInformation   OperatorSpecInfoList      OPTIONAL,
...
}

ContentTransaction ::= [APPLICATION 17] SEQUENCE
{
 contentTransactionBasicInfo ContentTransactionBasicInfo OPTIONAL, -- *m.m.
 chargedPartyInformation     ChargedPartyInformation     OPTIONAL, -- *m.m.
 servingPartiesInformation   ServingPartiesInformation   OPTIONAL, -- *m.m.
 contentServiceUsed          ContentServiceUsedList      OPTIONAL, -- *m.m.
 operatorSpecInformation     OperatorSpecInfoList        OPTIONAL,
...
}

LocationService ::= [APPLICATION 297] SEQUENCE
{
    rapFileSequenceNumber	  RapFileSequenceNumber       OPTIONAL,
    recEntityCode			  RecEntityCode               OPTIONAL, -- *m.m.
    callReference			  CallReference               OPTIONAL,
    trackingCustomerInformation TrackingCustomerInformation OPTIONAL,
    lCSSPInformation         	  LCSSPInformation            OPTIONAL,
    trackedCustomerInformation  TrackedCustomerInformation  OPTIONAL,
    locationServiceUsage	  LocationServiceUsage        OPTIONAL, -- *m.m.
    operatorSpecInformation	  OperatorSpecInfoList        OPTIONAL,
...
}

MessagingEvent ::= [APPLICATION 433] SEQUENCE
{
    messagingEventService	MessagingEventService     OPTIONAL, -- *m.m.
    chargedParty              ChargedParty              OPTIONAL, -- *m.m.
    rapFileSequenceNumber	RapFileSequenceNumber     OPTIONAL,
    simToolkitIndicator		SimToolkitIndicator	  OPTIONAL,
    geographicalLocation	GeographicalLocation      OPTIONAL,
    eventReference            EventReference		  OPTIONAL, -- *m.m.

    recEntityCodeList  		RecEntityCodeList 	  OPTIONAL, -- *m.m.  
    networkElementList		NetworkElementList	  OPTIONAL,
    locationArea              LocationArea  		  OPTIONAL,
    cellId          		CellId    			  OPTIONAL,    
    serviceStartTimestamp	ServiceStartTimestamp	  OPTIONAL, -- *m.m.
    nonChargedParty		NonChargedParty		  OPTIONAL,
    exchangeRateCode		ExchangeRateCode		  OPTIONAL,
    callTypeGroup			CallTypeGroup		  OPTIONAL, -- *m.m.
    charge				Charge			  OPTIONAL, -- *m.m.
    taxInformationList		TaxInformationList	  OPTIONAL,
    operatorSpecInformation   OperatorSpecInfoList      OPTIONAL,
...
}

MobileSession ::= [APPLICATION 434] SEQUENCE
{
    mobileSessionService	MobileSessionService      OPTIONAL, -- *m.m.
    chargedParty              ChargedParty              OPTIONAL, -- *m.m.
    rapFileSequenceNumber	RapFileSequenceNumber     OPTIONAL,
    simToolkitIndicator		SimToolkitIndicator	  OPTIONAL,
    geographicalLocation	GeographicalLocation      OPTIONAL,
    locationArea              LocationArea  		  OPTIONAL,
    cellId          		CellId    			  OPTIONAL,
    eventReference            EventReference		  OPTIONAL, -- *m.m.

    recEntityCodeList  		RecEntityCodeList 	  OPTIONAL, -- *m.m.
    serviceStartTimestamp	ServiceStartTimestamp	  OPTIONAL, -- *m.m.
    causeForTerm              CauseForTerm	        OPTIONAL,
    totalCallEventDuration	TotalCallEventDuration	  OPTIONAL, -- *m.m.
    nonChargedParty		NonChargedParty		  OPTIONAL,
    sessionChargeInfoList     SessionChargeInfoList     OPTIONAL, -- *m.m.
    operatorSpecInformation   OperatorSpecInfoList      OPTIONAL,
...
}

AuditControlInfo ::= [APPLICATION 15] SEQUENCE
{
    earliestCallTimeStamp    	  EarliestCallTimeStamp       OPTIONAL,
    latestCallTimeStamp      	  LatestCallTimeStamp         OPTIONAL,
    totalCharge              	  TotalCharge                 OPTIONAL, -- *m.m.
    totalChargeRefund        	  TotalChargeRefund           OPTIONAL,
    totalTaxRefund           	  TotalTaxRefund              OPTIONAL,
    totalTaxValue 		  TotalTaxValue               OPTIONAL, -- *m.m.
    totalDiscountValue		  TotalDiscountValue          OPTIONAL, -- *m.m.
    totalDiscountRefund		  TotalDiscountRefund         OPTIONAL,
    totalAdvisedChargeValueList TotalAdvisedChargeValueList OPTIONAL,
    callEventDetailsCount	  CallEventDetailsCount       OPTIONAL, -- *m.m.
    operatorSpecInformation	  OperatorSpecInfoList        OPTIONAL,
...
}


-- 
-- Tap data items and groups of data items
--

AccessPointNameNI ::= [APPLICATION 261] AsciiString --(SIZE(1..63))

AccessPointNameOI ::= [APPLICATION 262] AsciiString --(SIZE(1..37))

ActualDeliveryTimeStamp ::= [APPLICATION 302] DateTime

AddressStringDigits ::= BCDString

AdvisedCharge ::= [APPLICATION 349] Charge
 
AdvisedChargeCurrency ::= [APPLICATION 348] Currency
 
AdvisedChargeInformation ::= [APPLICATION 351] SEQUENCE
{
    paidIndicator         PaidIndicator         OPTIONAL,
    paymentMethod         PaymentMethod         OPTIONAL,
    advisedChargeCurrency AdvisedChargeCurrency OPTIONAL,
    advisedCharge         AdvisedCharge         OPTIONAL, -- *m.m.
    commission            Commission            OPTIONAL,
...
}
 
AgeOfLocation ::= [APPLICATION 396] INTEGER

BasicService ::= [APPLICATION 36] SEQUENCE
{
    serviceCode                 BasicServiceCode       OPTIONAL, -- *m.m.
    transparencyIndicator       TransparencyIndicator  OPTIONAL,
    fnur                        Fnur                   OPTIONAL,
    userProtocolIndicator       UserProtocolIndicator  OPTIONAL,
    guaranteedBitRate           GuaranteedBitRate      OPTIONAL,
    maximumBitRate              MaximumBitRate         OPTIONAL,
...
}

BasicServiceCode ::= [APPLICATION 426] CHOICE 
{
    teleServiceCode      TeleServiceCode,
    bearerServiceCode    BearerServiceCode,
...
}

BasicServiceCodeList ::= [APPLICATION 37] SEQUENCE OF BasicServiceCode

BasicServiceUsed ::= [APPLICATION 39] SEQUENCE
{
    basicService                BasicService          OPTIONAL, -- *m.m.
    chargingTimeStamp           ChargingTimeStamp     OPTIONAL,
    chargeInformationList       ChargeInformationList OPTIONAL, -- *m.m.
    hSCSDIndicator              HSCSDIndicator        OPTIONAL,
...
}

BasicServiceUsedList ::= [APPLICATION 38] SEQUENCE OF BasicServiceUsed

BearerServiceCode ::= [APPLICATION 40] HexString --(SIZE(2))

EventReference ::= [APPLICATION 435]  AsciiString


CalledNumber ::= [APPLICATION 407] AddressStringDigits

CalledPlace ::= [APPLICATION 42] AsciiString

CalledRegion ::= [APPLICATION 46] AsciiString

CallEventDetailsCount ::= [APPLICATION 43] INTEGER 

CallEventStartTimeStamp ::= [APPLICATION 44] DateTime

CallingNumber ::= [APPLICATION 405] AddressStringDigits

CallOriginator ::= [APPLICATION 41]  SEQUENCE
{
    callingNumber               CallingNumber		OPTIONAL,
    clirIndicator               ClirIndicator         OPTIONAL,
    sMSOriginator               SMSOriginator         OPTIONAL,
...
}

CallReference ::= [APPLICATION 45] OCTET STRING --(SIZE(1..8))

CallTypeGroup ::= [APPLICATION 258] SEQUENCE
{
    callTypeLevel1      CallTypeLevel1           OPTIONAL, -- *m.m.
    callTypeLevel2      CallTypeLevel2           OPTIONAL, -- *m.m.
    callTypeLevel3      CallTypeLevel3           OPTIONAL, -- *m.m.
...
}

CallTypeLevel1 ::= [APPLICATION 259] INTEGER

CallTypeLevel2 ::= [APPLICATION 255] INTEGER

CallTypeLevel3 ::= [APPLICATION 256] INTEGER

CamelDestinationNumber ::= [APPLICATION 404] AddressStringDigits

CamelInvocationFee ::= [APPLICATION 422] AbsoluteAmount

CamelServiceKey ::= [APPLICATION 55] INTEGER

CamelServiceLevel ::= [APPLICATION 56] INTEGER

CamelServiceUsed ::= [APPLICATION 57] SEQUENCE
{
    camelServiceLevel         CamelServiceLevel          	OPTIONAL,
    camelServiceKey           CamelServiceKey            	OPTIONAL, -- *m.m.
    defaultCallHandling       DefaultCallHandlingIndicator	OPTIONAL,
    exchangeRateCode          ExchangeRateCode 			OPTIONAL,
    taxInformation            TaxInformationList           	OPTIONAL,
    discountInformation       DiscountInformation          	OPTIONAL,
    camelInvocationFee        CamelInvocationFee           	OPTIONAL,
    threeGcamelDestination    ThreeGcamelDestination       	OPTIONAL,
    cseInformation            CseInformation               	OPTIONAL,
...
}

CauseForTerm ::= [APPLICATION 58] INTEGER

CellId ::= [APPLICATION 59] INTEGER 

Charge ::= [APPLICATION 62] AbsoluteAmount

ChargeableSubscriber ::= [APPLICATION 427] CHOICE 
{
    simChargeableSubscriber SimChargeableSubscriber,
    minChargeableSubscriber MinChargeableSubscriber,
...
}

ChargeableUnits ::= [APPLICATION 65]  INTEGER

ChargeDetail ::= [APPLICATION 63] SEQUENCE
{
    chargeType              ChargeType         		OPTIONAL, -- *m.m.
    charge                  Charge             		OPTIONAL, -- *m.m.
    chargeableUnits         ChargeableUnits    		OPTIONAL,
    chargedUnits            ChargedUnits       		OPTIONAL,
    chargeDetailTimeStamp   ChargeDetailTimeStamp	OPTIONAL,
...
}

ChargeDetailList ::= [APPLICATION 64] SEQUENCE OF ChargeDetail

ChargeDetailTimeStamp ::= [APPLICATION 410] ChargingTimeStamp

ChargedItem ::= [APPLICATION 66]  AsciiString --(SIZE(1))

ChargedParty ::= [APPLICATION 436] SEQUENCE
{
    imsi     			Imsi 			  	OPTIONAL, -- *m.m.
    msisdn				Msisdn              	OPTIONAL,         
    publicUserId			PublicUserId	  	OPTIONAL,
    homeBid				HomeBid		  	OPTIONAL,
    homeLocationDescription	HomeLocationDescription OPTIONAL,
    imei				Imei		   		OPTIONAL,
...
}

ChargedPartyEquipment ::= [APPLICATION 323] SEQUENCE
{
    equipmentIdType EquipmentIdType OPTIONAL, -- *m.m.
    equipmentId     EquipmentId     OPTIONAL, -- *m.m.
...
}
 
ChargedPartyHomeIdentification ::= [APPLICATION 313] SEQUENCE
{
    homeIdType     HomeIdType     OPTIONAL, -- *m.m.
    homeIdentifier HomeIdentifier OPTIONAL, -- *m.m.
...
}

ChargedPartyHomeIdList ::= [APPLICATION 314] SEQUENCE OF
                                             ChargedPartyHomeIdentification

ChargedPartyIdentification ::= [APPLICATION 309] SEQUENCE
{
    chargedPartyIdType         ChargedPartyIdType         OPTIONAL, -- *m.m.
    chargedPartyIdentifier     ChargedPartyIdentifier     OPTIONAL, -- *m.m.
...
}

ChargedPartyIdentifier ::= [APPLICATION 287] AsciiString

ChargedPartyIdList ::= [APPLICATION 310] SEQUENCE OF ChargedPartyIdentification

ChargedPartyIdType ::= [APPLICATION 305] INTEGER

ChargedPartyInformation ::= [APPLICATION 324] SEQUENCE
{
    chargedPartyIdList       ChargedPartyIdList        OPTIONAL, -- *m.m.
    chargedPartyHomeIdList   ChargedPartyHomeIdList    OPTIONAL,
    chargedPartyLocationList ChargedPartyLocationList  OPTIONAL,
    chargedPartyEquipment    ChargedPartyEquipment     OPTIONAL,
...
}
 
ChargedPartyLocation ::= [APPLICATION 320] SEQUENCE
{
    locationIdType     LocationIdType     OPTIONAL, -- *m.m.
    locationIdentifier LocationIdentifier OPTIONAL, -- *m.m.
...
}
 
ChargedPartyLocationList ::= [APPLICATION 321] SEQUENCE OF ChargedPartyLocation
 
ChargedPartyStatus ::= [APPLICATION 67] INTEGER 

ChargedUnits ::= [APPLICATION 68]  INTEGER 

ChargeInformation ::= [APPLICATION 69] SEQUENCE
{
    chargedItem         ChargedItem         OPTIONAL, -- *m.m.
    exchangeRateCode    ExchangeRateCode    OPTIONAL,
    callTypeGroup       CallTypeGroup       OPTIONAL,
    chargeDetailList    ChargeDetailList    OPTIONAL, -- *m.m.
    taxInformation      TaxInformationList  OPTIONAL,
    discountInformation DiscountInformation OPTIONAL,
...
}

ChargeInformationList ::= [APPLICATION 70] SEQUENCE OF ChargeInformation

ChargeRefundIndicator ::= [APPLICATION 344] INTEGER
 
ChargeType ::= [APPLICATION 71] NumberString --(SIZE(2..3))

ChargingId ::= [APPLICATION 72] INTEGER

ChargingPoint ::= [APPLICATION 73]  AsciiString --(SIZE(1))

ChargingTimeStamp ::= [APPLICATION 74]  DateTime

ClirIndicator ::= [APPLICATION 75] INTEGER

Commission ::= [APPLICATION 350] Charge
 
CompletionTimeStamp ::= [APPLICATION 76] DateTime

ContentChargingPoint ::= [APPLICATION 345] INTEGER
 
ContentProvider ::= [APPLICATION 327] SEQUENCE
{
    contentProviderIdType     ContentProviderIdType     OPTIONAL, -- *m.m.
    contentProviderIdentifier ContentProviderIdentifier OPTIONAL, -- *m.m.
...
}
 
ContentProviderIdentifier ::= [APPLICATION 292] AsciiString

ContentProviderIdList ::= [APPLICATION 328] SEQUENCE OF ContentProvider

ContentProviderIdType ::= [APPLICATION 291] INTEGER

ContentProviderName ::= [APPLICATION 334] AsciiString
 
ContentServiceUsed ::= [APPLICATION 352] SEQUENCE
{
    contentTransactionCode       ContentTransactionCode       OPTIONAL, -- *m.m.
    contentTransactionType       ContentTransactionType       OPTIONAL, -- *m.m.
    objectType                   ObjectType                   OPTIONAL,
    transactionDescriptionSupp   TransactionDescriptionSupp   OPTIONAL,
    transactionShortDescription  TransactionShortDescription  OPTIONAL, -- *m.m.
    transactionDetailDescription TransactionDetailDescription OPTIONAL,
    transactionIdentifier   	   TransactionIdentifier        OPTIONAL, -- *m.m.
    transactionAuthCode          TransactionAuthCode          OPTIONAL,
    dataVolumeIncoming           DataVolumeIncoming           OPTIONAL,
    dataVolumeOutgoing           DataVolumeOutgoing           OPTIONAL,
    totalDataVolume              TotalDataVolume              OPTIONAL,
    chargeRefundIndicator        ChargeRefundIndicator        OPTIONAL,
    contentChargingPoint         ContentChargingPoint         OPTIONAL,
    chargeInformationList        ChargeInformationList        OPTIONAL,
    advisedChargeInformation     AdvisedChargeInformation     OPTIONAL,
...
}

ContentServiceUsedList ::= [APPLICATION 285] SEQUENCE OF ContentServiceUsed
 
ContentTransactionBasicInfo ::= [APPLICATION 304] SEQUENCE
{
    rapFileSequenceNumber      RapFileSequenceNumber      OPTIONAL,
    orderPlacedTimeStamp       OrderPlacedTimeStamp       OPTIONAL,
    requestedDeliveryTimeStamp RequestedDeliveryTimeStamp OPTIONAL,
    actualDeliveryTimeStamp    ActualDeliveryTimeStamp    OPTIONAL,
    totalTransactionDuration   TotalTransactionDuration   OPTIONAL,
    transactionStatus          TransactionStatus          OPTIONAL,
...
}

ContentTransactionCode ::= [APPLICATION 336] INTEGER
 
ContentTransactionType ::= [APPLICATION 337] INTEGER
 
CseInformation ::= [APPLICATION 79] OCTET STRING --(SIZE(1..40))

CurrencyConversion ::= [APPLICATION 106] SEQUENCE
{
    exchangeRateCode      ExchangeRateCode      OPTIONAL, -- *m.m.
    numberOfDecimalPlaces NumberOfDecimalPlaces OPTIONAL, -- *m.m.
    exchangeRate          ExchangeRate          OPTIONAL, -- *m.m.
...
}

CurrencyConversionList ::= [APPLICATION 80] SEQUENCE OF CurrencyConversion

CustomerIdentifier ::= [APPLICATION 364] AsciiString

CustomerIdType ::= [APPLICATION 363] INTEGER

DataVolume ::= INTEGER 

DataVolumeIncoming ::= [APPLICATION 250] DataVolume

DataVolumeOutgoing ::= [APPLICATION 251] DataVolume

--
--  The following datatypes are used to denote timestamps.
--  Each timestamp consists of a local timestamp and a
--  corresponding UTC time offset. 
--  Except for the timestamps used within the Batch Control 
--  Information and the Audit Control Information 
--  the UTC time offset is identified by a code referencing
--  the UtcTimeOffsetInfo.
--  
 
--
-- We start with the “short” datatype referencing the 
-- UtcTimeOffsetInfo.
-- 

DateTime ::= SEQUENCE 
{
     -- 
     -- Local timestamps are noted in the format
     --
     --     CCYYMMDDhhmmss
     --
     -- where CC  =  century  (‘19’, ‘20’,...)
     --       YY  =  year     (‘00’ – ‘99’)
     --       MM  =  month    (‘01’, ‘02’, ... , ‘12’)
     --       DD  =  day      (‘01’, ‘02’, ... , ‘31’)
     --       hh  =  hour     (‘00’, ‘01’, ... , ‘23’)
     --       mm  =  minutes  (‘00’, ‘01’, ... , ‘59’)
     --       ss  =  seconds  (‘00’, ‘01’, ... , ‘59’)
     -- 
    localTimeStamp     LocalTimeStamp    OPTIONAL, -- *m.m.
    utcTimeOffsetCode  UtcTimeOffsetCode OPTIONAL, -- *m.m.
...
}

--
-- The following version is the “long” datatype
-- containing the UTC time offset directly. 
--

DateTimeLong ::= SEQUENCE 
{
    localTimeStamp     LocalTimeStamp OPTIONAL, -- *m.m.
    utcTimeOffset      UtcTimeOffset  OPTIONAL, -- *m.m.
...
}

DefaultCallHandlingIndicator ::= [APPLICATION 87] INTEGER

DepositTimeStamp ::= [APPLICATION 88] DateTime

Destination ::= [APPLICATION 89] SEQUENCE
{
    calledNumber                CalledNumber  		OPTIONAL,
    dialledDigits               DialledDigits         OPTIONAL,
    calledPlace                 CalledPlace           OPTIONAL,
    calledRegion                CalledRegion          OPTIONAL,
    sMSDestinationNumber        SMSDestinationNumber  OPTIONAL,
...
}

DestinationNetwork ::= [APPLICATION 90] NetworkId 

DialledDigits ::= [APPLICATION 279] AsciiString

Discount ::= [APPLICATION 412] DiscountValue

DiscountableAmount ::= [APPLICATION 423] AbsoluteAmount

DiscountApplied ::= [APPLICATION 428] CHOICE 
{
    fixedDiscountValue    FixedDiscountValue, 
    discountRate          DiscountRate,
...
}

DiscountCode ::= [APPLICATION 91] INTEGER

DiscountInformation ::= [APPLICATION 96] SEQUENCE
{
    discountCode        DiscountCode		OPTIONAL, -- *m.m.
    discount            Discount      		OPTIONAL,
    discountableAmount  DiscountableAmount	OPTIONAL,
...
}

Discounting ::= [APPLICATION 94] SEQUENCE
{
    discountCode    DiscountCode    OPTIONAL, -- *m.m.
    discountApplied DiscountApplied OPTIONAL, -- *m.m.
...
}

DiscountingList ::= [APPLICATION 95]  SEQUENCE OF Discounting

DiscountRate ::= [APPLICATION 92] PercentageRate

DiscountValue ::= AbsoluteAmount

DistanceChargeBandCode ::= [APPLICATION 98] AsciiString --(SIZE(1))

EarliestCallTimeStamp ::= [APPLICATION 101] DateTimeLong

ElementId ::= [APPLICATION 437] AsciiString

ElementType ::= [APPLICATION 438] INTEGER

EquipmentId ::= [APPLICATION 290] AsciiString

EquipmentIdType ::= [APPLICATION 322] INTEGER

Esn ::= [APPLICATION 103] NumberString

ExchangeRate ::= [APPLICATION 104] INTEGER

ExchangeRateCode ::= [APPLICATION 105] Code

FileAvailableTimeStamp ::= [APPLICATION 107] DateTimeLong

FileCreationTimeStamp ::= [APPLICATION 108] DateTimeLong

FileSequenceNumber ::= [APPLICATION 109] NumberString --(SIZE(5))

FileTypeIndicator ::= [APPLICATION 110] AsciiString --(SIZE(1))

FixedDiscountValue ::= [APPLICATION 411] DiscountValue

Fnur ::= [APPLICATION 111] INTEGER

GeographicalLocation ::= [APPLICATION 113]  SEQUENCE
{
    servingNetwork              ServingNetwork       		OPTIONAL,
    servingBid                  ServingBid           		OPTIONAL,
    servingLocationDescription  ServingLocationDescription  OPTIONAL,
...
}

GprsBasicCallInformation ::= [APPLICATION 114] SEQUENCE
{
    gprsChargeableSubscriber    GprsChargeableSubscriber OPTIONAL, -- *m.m.
    rapFileSequenceNumber       RapFileSequenceNumber    OPTIONAL,
    gprsDestination             GprsDestination          OPTIONAL, -- *m.m.
    callEventStartTimeStamp     CallEventStartTimeStamp  OPTIONAL, -- *m.m.
    totalCallEventDuration      TotalCallEventDuration   OPTIONAL, -- *m.m.
    causeForTerm                CauseForTerm             OPTIONAL,
    partialTypeIndicator        PartialTypeIndicator     OPTIONAL,
    pDPContextStartTimestamp    PDPContextStartTimestamp OPTIONAL,
    networkInitPDPContext       NetworkInitPDPContext    OPTIONAL,
    chargingId                  ChargingId               OPTIONAL, -- *m.m.
...
}

GprsChargeableSubscriber ::= [APPLICATION 115] SEQUENCE
{
    chargeableSubscriber        ChargeableSubscriber    OPTIONAL,
    pdpAddress                  PdpAddress              OPTIONAL,
    networkAccessIdentifier     NetworkAccessIdentifier OPTIONAL,
...
}

GprsDestination ::= [APPLICATION 116] SEQUENCE
{
    accessPointNameNI           AccessPointNameNI      OPTIONAL, -- *m.m.
    accessPointNameOI           AccessPointNameOI      OPTIONAL,
...
}

GprsLocationInformation ::= [APPLICATION 117] SEQUENCE
{
    gprsNetworkLocation         GprsNetworkLocation     OPTIONAL, -- *m.m.
    homeLocationInformation     HomeLocationInformation OPTIONAL,
    geographicalLocation        GeographicalLocation    OPTIONAL, 
...
} 

GprsNetworkLocation ::= [APPLICATION 118] SEQUENCE
{
    recEntity                   RecEntityCodeList OPTIONAL, -- *m.m.
    locationArea                LocationArea      OPTIONAL,
    cellId                      CellId            OPTIONAL,
...
}

GprsServiceUsed ::= [APPLICATION 121]  SEQUENCE
{
    iMSSignallingContext        IMSSignallingContext  OPTIONAL,
    dataVolumeIncoming          DataVolumeIncoming    OPTIONAL, -- *m.m.
    dataVolumeOutgoing          DataVolumeOutgoing    OPTIONAL, -- *m.m.
    chargeInformationList       ChargeInformationList OPTIONAL, -- *m.m.
...
}

GsmChargeableSubscriber ::= [APPLICATION 286] SEQUENCE
{
    imsi     Imsi   OPTIONAL,
    msisdn   Msisdn OPTIONAL,
...
}

GuaranteedBitRate ::= [APPLICATION 420] OCTET STRING --(SIZE (1))

HomeBid ::= [APPLICATION 122]  Bid

HomeIdentifier ::= [APPLICATION 288] AsciiString

HomeIdType ::= [APPLICATION 311] INTEGER

HomeLocationDescription ::= [APPLICATION 413] LocationDescription

HomeLocationInformation ::= [APPLICATION 123] SEQUENCE
{
    homeBid                     HomeBid             		OPTIONAL, -- *m.m.
    homeLocationDescription     HomeLocationDescription	OPTIONAL, -- *m.m.
...
}

HorizontalAccuracyDelivered ::= [APPLICATION 392] INTEGER

HorizontalAccuracyRequested ::= [APPLICATION 385] INTEGER

HSCSDIndicator ::= [APPLICATION 424] AsciiString --(SIZE(1))

Imei ::= [APPLICATION 128] BCDString --(SIZE(7..8))

ImeiOrEsn ::= [APPLICATION 429] CHOICE 
{
    imei  Imei,
    esn   Esn,
...
} 

Imsi ::= [APPLICATION 129] BCDString --(SIZE(3..8))

IMSSignallingContext ::= [APPLICATION 418] INTEGER

InternetServiceProvider ::= [APPLICATION 329] SEQUENCE
{
    ispIdType        IspIdType        OPTIONAL, -- *m.m.
    ispIdentifier    IspIdentifier    OPTIONAL, -- *m.m.
...
}
 
InternetServiceProviderIdList ::= [APPLICATION 330] SEQUENCE OF InternetServiceProvider

IspIdentifier ::= [APPLICATION 294] AsciiString
 
IspIdType ::= [APPLICATION 293] INTEGER

ISPList ::= [APPLICATION 378] SEQUENCE OF InternetServiceProvider

NetworkIdType ::= [APPLICATION 331] INTEGER

NetworkIdentifier ::= [APPLICATION 295] AsciiString

Network ::= [APPLICATION 332] SEQUENCE
{
    networkIdType     NetworkIdType     OPTIONAL, -- *m.m.
    networkIdentifier NetworkIdentifier OPTIONAL, -- *m.m.
...
}
 
NetworkList ::= [APPLICATION 333] SEQUENCE OF Network
 
LatestCallTimeStamp ::= [APPLICATION 133] DateTimeLong

LCSQosDelivered ::= [APPLICATION 390] SEQUENCE
{
    lCSTransactionStatus          LCSTransactionStatus        OPTIONAL,
    horizontalAccuracyDelivered   HorizontalAccuracyDelivered OPTIONAL,
    verticalAccuracyDelivered     VerticalAccuracyDelivered   OPTIONAL,
    responseTime                  ResponseTime                OPTIONAL,
    positioningMethod             PositioningMethod           OPTIONAL,
    trackingPeriod                TrackingPeriod              OPTIONAL,
    trackingFrequency             TrackingFrequency           OPTIONAL,
    ageOfLocation                 AgeOfLocation               OPTIONAL,
...
}

LCSQosRequested ::= [APPLICATION 383] SEQUENCE
{
    lCSRequestTimestamp           LCSRequestTimestamp         OPTIONAL, -- *m.m.
    horizontalAccuracyRequested   HorizontalAccuracyRequested OPTIONAL,
    verticalAccuracyRequested     VerticalAccuracyRequested   OPTIONAL,
    responseTimeCategory          ResponseTimeCategory        OPTIONAL,
    trackingPeriod                TrackingPeriod              OPTIONAL,
    trackingFrequency             TrackingFrequency           OPTIONAL,
...
}

LCSRequestTimestamp ::= [APPLICATION 384] DateTime

LCSSPIdentification ::= [APPLICATION 375] SEQUENCE
{
 contentProviderIdType         ContentProviderIdType     OPTIONAL, -- *m.m.
 contentProviderIdentifier     ContentProviderIdentifier OPTIONAL, -- *m.m.
...
}

LCSSPIdentificationList ::= [APPLICATION 374] SEQUENCE OF LCSSPIdentification

LCSSPInformation ::= [APPLICATION 373] SEQUENCE
{
    lCSSPIdentificationList       LCSSPIdentificationList OPTIONAL, -- *m.m.
    iSPList                       ISPList                 OPTIONAL,
    networkList                   NetworkList             OPTIONAL,
...
}

LCSTransactionStatus ::= [APPLICATION 391] INTEGER

LocalCurrency ::= [APPLICATION 135] Currency

LocalTimeStamp ::= [APPLICATION 16] NumberString --(SIZE(14))

LocationArea ::= [APPLICATION 136] INTEGER 

LocationDescription ::= AsciiString

LocationIdentifier ::= [APPLICATION 289] AsciiString

LocationIdType ::= [APPLICATION 315] INTEGER

LocationInformation ::= [APPLICATION 138]  SEQUENCE
{
    networkLocation             NetworkLocation         OPTIONAL, -- *m.m.
    homeLocationInformation     HomeLocationInformation OPTIONAL,
    geographicalLocation        GeographicalLocation    OPTIONAL,
...
} 

LocationServiceUsage ::= [APPLICATION 382] SEQUENCE
{
    lCSQosRequested               LCSQosRequested       OPTIONAL, -- *m.m.
    lCSQosDelivered               LCSQosDelivered       OPTIONAL,
    chargingTimeStamp             ChargingTimeStamp     OPTIONAL,
    chargeInformationList         ChargeInformationList OPTIONAL, -- *m.m.
...
}

MaximumBitRate ::= [APPLICATION 421] OCTET STRING --(SIZE (1))

Mdn ::= [APPLICATION 253] NumberString

MessageDescription ::= [APPLICATION 142] AsciiString

MessageDescriptionCode ::= [APPLICATION 141] Code

MessageDescriptionInformation ::= [APPLICATION 143] SEQUENCE
{
    messageDescriptionCode MessageDescriptionCode OPTIONAL, -- *m.m.
    messageDescription     MessageDescription     OPTIONAL, -- *m.m.
...
}

MessageStatus ::= [APPLICATION 144] INTEGER

MessageType ::= [APPLICATION 145] INTEGER

MessagingEventService ::= [APPLICATION 439] INTEGER

Min ::= [APPLICATION 146] NumberString --(SIZE(2..15)) 

MinChargeableSubscriber ::= [APPLICATION 254] SEQUENCE
{
    min     Min    OPTIONAL, -- *m.m.
    mdn     Mdn    OPTIONAL,
...
}

MoBasicCallInformation ::= [APPLICATION 147] SEQUENCE
{
    chargeableSubscriber        ChargeableSubscriber    OPTIONAL, -- *m.m.
    rapFileSequenceNumber       RapFileSequenceNumber   OPTIONAL,
    destination                 Destination             OPTIONAL,
    destinationNetwork          DestinationNetwork      OPTIONAL,
    callEventStartTimeStamp     CallEventStartTimeStamp OPTIONAL, -- *m.m.
    totalCallEventDuration      TotalCallEventDuration  OPTIONAL, -- *m.m.
    simToolkitIndicator         SimToolkitIndicator     OPTIONAL,
    causeForTerm                CauseForTerm            OPTIONAL,
...
}

MobileSessionService ::= [APPLICATION 440] INTEGER      

Msisdn ::= [APPLICATION 152] BCDString --(SIZE(1..9))

MtBasicCallInformation ::= [APPLICATION 153] SEQUENCE
{
    chargeableSubscriber        ChargeableSubscriber    OPTIONAL, -- *m.m.
    rapFileSequenceNumber       RapFileSequenceNumber   OPTIONAL,
    callOriginator              CallOriginator          OPTIONAL,
    originatingNetwork          OriginatingNetwork      OPTIONAL,
    callEventStartTimeStamp     CallEventStartTimeStamp OPTIONAL, -- *m.m.
    totalCallEventDuration      TotalCallEventDuration  OPTIONAL, -- *m.m.
    simToolkitIndicator         SimToolkitIndicator     OPTIONAL,
    causeForTerm                CauseForTerm            OPTIONAL,
...
}

NetworkAccessIdentifier ::= [APPLICATION 417] AsciiString

NetworkElement ::= [APPLICATION 441]  SEQUENCE
{
elementType             ElementType  OPTIONAL, -- *m.m.
elementId               ElementId    OPTIONAL, -- *m.m.
...
}

NetworkElementList ::= [APPLICATION 442] SEQUENCE OF NetworkElement

NetworkId ::= AsciiString --(SIZE(1..6))

NetworkInitPDPContext ::= [APPLICATION 245] INTEGER

NetworkLocation ::= [APPLICATION 156]  SEQUENCE
{
    recEntityCode               RecEntityCode OPTIONAL, -- *m.m.
    callReference               CallReference OPTIONAL,
    locationArea                LocationArea  OPTIONAL,
    cellId                      CellId        OPTIONAL,
...
}

NonChargedNumber ::= [APPLICATION 402] AsciiString

NonChargedParty ::= [APPLICATION 443]  SEQUENCE
{
    nonChargedPartyNumber       NonChargedPartyNumber	 OPTIONAL,
    nonChargedPublicUserId      NonChargedPublicUserId OPTIONAL,
...
}

NonChargedPartyNumber ::= [APPLICATION 444] AddressStringDigits

NonChargedPublicUserId ::= [APPLICATION 445] AsciiString 

NumberOfDecimalPlaces ::= [APPLICATION 159] INTEGER

ObjectType ::= [APPLICATION 281] INTEGER

OperatorSpecInfoList ::= [APPLICATION 162] SEQUENCE OF OperatorSpecInformation

OperatorSpecInformation ::= [APPLICATION 163] AsciiString

OrderPlacedTimeStamp ::= [APPLICATION 300] DateTime

OriginatingNetwork ::= [APPLICATION 164] NetworkId 

PacketDataProtocolAddress ::= [APPLICATION 165] AsciiString 

PaidIndicator ::= [APPLICATION 346] INTEGER
 
PartialTypeIndicator ::=  [APPLICATION 166] AsciiString --(SIZE(1))

PaymentMethod ::= [APPLICATION 347] INTEGER

PdpAddress ::= [APPLICATION 167] PacketDataProtocolAddress

PDPContextStartTimestamp ::= [APPLICATION 260] DateTime

PlmnId ::= [APPLICATION 169] AsciiString --(SIZE(5))

PositioningMethod ::= [APPLICATION 395] INTEGER

PriorityCode ::= [APPLICATION 170] INTEGER

PublicUserId ::= [APPLICATION 446] AsciiString 

RapFileSequenceNumber ::= [APPLICATION 181]  FileSequenceNumber

RecEntityCode ::= [APPLICATION 184] Code

RecEntityCodeList ::= [APPLICATION 185] SEQUENCE OF RecEntityCode

RecEntityId ::= [APPLICATION 400] AsciiString

RecEntityInfoList ::= [APPLICATION 188] SEQUENCE OF RecEntityInformation

RecEntityInformation ::= [APPLICATION 183] SEQUENCE
{
    recEntityCode  RecEntityCode OPTIONAL, -- *m.m.
    recEntityType  RecEntityType OPTIONAL, -- *m.m.
    recEntityId    RecEntityId   OPTIONAL, -- *m.m.
...
}
 
RecEntityType ::= [APPLICATION 186] INTEGER

Recipient ::= [APPLICATION 182]  PlmnId

ReleaseVersionNumber ::= [APPLICATION 189] INTEGER

RequestedDeliveryTimeStamp ::= [APPLICATION 301] DateTime

ResponseTime ::= [APPLICATION 394] INTEGER

ResponseTimeCategory ::= [APPLICATION 387] INTEGER

ScuBasicInformation ::= [APPLICATION 191] SEQUENCE
{
    chargeableSubscriber      ScuChargeableSubscriber    OPTIONAL, -- *m.m.
    chargedPartyStatus        ChargedPartyStatus         OPTIONAL, -- *m.m.
    nonChargedNumber          NonChargedNumber           OPTIONAL, -- *m.m.
    clirIndicator             ClirIndicator              OPTIONAL,
    originatingNetwork        OriginatingNetwork         OPTIONAL,
    destinationNetwork        DestinationNetwork         OPTIONAL,
...
}

ScuChargeType ::= [APPLICATION 192]  SEQUENCE
{
    messageStatus               MessageStatus          OPTIONAL, -- *m.m.
    priorityCode                PriorityCode           OPTIONAL, -- *m.m.
    distanceChargeBandCode      DistanceChargeBandCode OPTIONAL,
    messageType                 MessageType            OPTIONAL, -- *m.m.
    messageDescriptionCode      MessageDescriptionCode OPTIONAL, -- *m.m.
...
}

ScuTimeStamps ::= [APPLICATION 193]  SEQUENCE
{
    depositTimeStamp            DepositTimeStamp    OPTIONAL, -- *m.m.
    completionTimeStamp         CompletionTimeStamp OPTIONAL, -- *m.m.
    chargingPoint               ChargingPoint       OPTIONAL, -- *m.m.
...
}

ScuChargeableSubscriber ::= [APPLICATION 430] CHOICE 
{
    gsmChargeableSubscriber    GsmChargeableSubscriber,
    minChargeableSubscriber    MinChargeableSubscriber,
...
}

Sender ::= [APPLICATION 196]  PlmnId

ServiceStartTimestamp ::= [APPLICATION 447] DateTime

ServingBid ::= [APPLICATION 198]  Bid

ServingLocationDescription ::= [APPLICATION 414] LocationDescription

ServingNetwork ::= [APPLICATION 195]  AsciiString

ServingPartiesInformation ::= [APPLICATION 335] SEQUENCE
{
  contentProviderName           ContentProviderName           OPTIONAL, -- *m.m.
  contentProviderIdList         ContentProviderIdList         OPTIONAL,
  internetServiceProviderIdList InternetServiceProviderIdList OPTIONAL,
  networkList                   NetworkList                   OPTIONAL,
...
}

SessionChargeInfoList ::= [APPLICATION 448] SEQUENCE OF SessionChargeInformation

SessionChargeInformation ::= [APPLICATION 449] SEQUENCE
{
chargedItem			ChargedItem 		 OPTIONAL, -- *m.m.    
exchangeRateCode		ExchangeRateCode         OPTIONAL,
    	callTypeGroup		CallTypeGroup		 OPTIONAL, -- *m.m.
    	chargeDetailList        ChargeDetailList         OPTIONAL, -- *m.m.
    	taxInformationList	TaxInformationList	 OPTIONAL,
...
}         
 
SimChargeableSubscriber ::= [APPLICATION 199] SEQUENCE
{
    imsi     Imsi   OPTIONAL, -- *m.m.
    msisdn   Msisdn OPTIONAL,
...
}

SimToolkitIndicator ::= [APPLICATION 200] AsciiString --(SIZE(1)) 

SMSDestinationNumber ::= [APPLICATION 419] AsciiString

SMSOriginator ::= [APPLICATION 425] AsciiString

SpecificationVersionNumber  ::= [APPLICATION 201] INTEGER

SsParameters ::= [APPLICATION 204] AsciiString --(SIZE(1..40))

SupplServiceActionCode ::= [APPLICATION 208] INTEGER

SupplServiceCode ::= [APPLICATION 209] HexString --(SIZE(2))

SupplServiceUsed ::= [APPLICATION 206] SEQUENCE
{
    supplServiceCode       SupplServiceCode       OPTIONAL, -- *m.m.
    supplServiceActionCode SupplServiceActionCode OPTIONAL, -- *m.m.
    ssParameters           SsParameters           OPTIONAL,
    chargingTimeStamp      ChargingTimeStamp      OPTIONAL,
    chargeInformation      ChargeInformation      OPTIONAL,
    basicServiceCodeList   BasicServiceCodeList   OPTIONAL,
...
}

TapCurrency ::= [APPLICATION 210] Currency

TapDecimalPlaces ::= [APPLICATION 244] INTEGER

TaxableAmount ::= [APPLICATION 398] AbsoluteAmount

Taxation ::= [APPLICATION 216] SEQUENCE
{
    taxCode      TaxCode      OPTIONAL, -- *m.m.
    taxType      TaxType      OPTIONAL, -- *m.m.
    taxRate      TaxRate      OPTIONAL,
    chargeType   ChargeType   OPTIONAL,
    taxIndicator TaxIndicator OPTIONAL,
...
}

TaxationList ::= [APPLICATION 211]  SEQUENCE OF Taxation

TaxCode ::= [APPLICATION 212] INTEGER

TaxIndicator ::= [APPLICATION 432] AsciiString --(SIZE(1))

TaxInformation ::= [APPLICATION 213] SEQUENCE
{
    taxCode          TaxCode       OPTIONAL, -- *m.m.
    taxValue         TaxValue      OPTIONAL, -- *m.m.
    taxableAmount    TaxableAmount OPTIONAL,
...
}

TaxInformationList ::= [APPLICATION 214]  SEQUENCE OF TaxInformation

-- The TaxRate item is of a fixed length to ensure that the full 5 
-- decimal places is provided.

TaxRate ::= [APPLICATION 215] NumberString --(SIZE(7))

TaxType ::= [APPLICATION 217] AsciiString --(SIZE(2))

TaxValue ::= [APPLICATION 397] AbsoluteAmount

TeleServiceCode ::= [APPLICATION 218] HexString --(SIZE(2))

ThirdPartyInformation ::= [APPLICATION 219]  SEQUENCE
{
    thirdPartyNumber            ThirdPartyNumber 	OPTIONAL,
    clirIndicator               ClirIndicator         OPTIONAL,
...
}

ThirdPartyNumber ::= [APPLICATION 403] AddressStringDigits

ThreeGcamelDestination ::= [APPLICATION 431] CHOICE
{
    camelDestinationNumber    CamelDestinationNumber,
    gprsDestination           GprsDestination,
...
}

TotalAdvisedCharge ::= [APPLICATION 356] AbsoluteAmount
 
TotalAdvisedChargeRefund ::= [APPLICATION 357] AbsoluteAmount
 
TotalAdvisedChargeValue ::= [APPLICATION 360] SEQUENCE
{
    advisedChargeCurrency    AdvisedChargeCurrency    OPTIONAL,
    totalAdvisedCharge       TotalAdvisedCharge       OPTIONAL, -- *m.m.
    totalAdvisedChargeRefund TotalAdvisedChargeRefund OPTIONAL,
    totalCommission          TotalCommission          OPTIONAL,
    totalCommissionRefund    TotalCommissionRefund    OPTIONAL,
...
}
 
TotalAdvisedChargeValueList ::= [APPLICATION 361] SEQUENCE OF TotalAdvisedChargeValue

TotalCallEventDuration ::= [APPLICATION 223] INTEGER 

TotalCharge ::= [APPLICATION 415] AbsoluteAmount

TotalChargeRefund ::= [APPLICATION 355] AbsoluteAmount
 
TotalCommission ::= [APPLICATION 358] AbsoluteAmount
 
TotalCommissionRefund ::= [APPLICATION 359] AbsoluteAmount
 
TotalDataVolume ::= [APPLICATION 343] DataVolume
 
TotalDiscountRefund ::= [APPLICATION 354] AbsoluteAmount
 
TotalDiscountValue ::= [APPLICATION 225] AbsoluteAmount

TotalTaxRefund ::= [APPLICATION 353] AbsoluteAmount
 
TotalTaxValue ::= [APPLICATION 226] AbsoluteAmount

TotalTransactionDuration ::= [APPLICATION 416] TotalCallEventDuration

TrackedCustomerEquipment ::= [APPLICATION 381] SEQUENCE
{
    equipmentIdType               EquipmentIdType OPTIONAL, -- *m.m.
    equipmentId                   EquipmentId     OPTIONAL, -- *m.m.
...
}

TrackedCustomerHomeId ::= [APPLICATION 377] SEQUENCE
{
    homeIdType                    HomeIdType     OPTIONAL, -- *m.m.
    homeIdentifier                HomeIdentifier OPTIONAL, -- *m.m.
...
}

TrackedCustomerHomeIdList ::= [APPLICATION 376] SEQUENCE OF TrackedCustomerHomeId

TrackedCustomerIdentification ::= [APPLICATION 372] SEQUENCE
{
    customerIdType                CustomerIdType     OPTIONAL, -- *m.m.
    customerIdentifier            CustomerIdentifier OPTIONAL, -- *m.m.
...
}

TrackedCustomerIdList ::= [APPLICATION 370] SEQUENCE OF TrackedCustomerIdentification

TrackedCustomerInformation ::= [APPLICATION 367] SEQUENCE
{
    trackedCustomerIdList         TrackedCustomerIdList     OPTIONAL, -- *m.m.
    trackedCustomerHomeIdList     TrackedCustomerHomeIdList OPTIONAL,
    trackedCustomerLocList        TrackedCustomerLocList    OPTIONAL,
    trackedCustomerEquipment      TrackedCustomerEquipment  OPTIONAL,
...
}

TrackedCustomerLocation ::= [APPLICATION 380] SEQUENCE
{
    locationIdType                LocationIdType     OPTIONAL, -- *m.m.
    locationIdentifier            LocationIdentifier OPTIONAL, -- *m.m.
...
}

TrackedCustomerLocList ::= [APPLICATION 379] SEQUENCE OF TrackedCustomerLocation

TrackingCustomerEquipment ::= [APPLICATION 371] SEQUENCE
{
    equipmentIdType               EquipmentIdType OPTIONAL, -- *m.m.
    equipmentId                   EquipmentId     OPTIONAL, -- *m.m.
...
}

TrackingCustomerHomeId ::= [APPLICATION 366] SEQUENCE
{
    homeIdType                    HomeIdType     OPTIONAL, -- *m.m.
    homeIdentifier                HomeIdentifier OPTIONAL, -- *m.m.
...
}

TrackingCustomerHomeIdList ::= [APPLICATION 365] SEQUENCE OF TrackingCustomerHomeId

TrackingCustomerIdentification ::= [APPLICATION 362] SEQUENCE
{
    customerIdType                CustomerIdType     OPTIONAL, -- *m.m.
    customerIdentifier            CustomerIdentifier OPTIONAL, -- *m.m.
...
}

TrackingCustomerIdList ::= [APPLICATION 299] SEQUENCE OF TrackingCustomerIdentification

TrackingCustomerInformation ::= [APPLICATION 298] SEQUENCE
{
    trackingCustomerIdList        TrackingCustomerIdList     OPTIONAL, -- *m.m.
    trackingCustomerHomeIdList    TrackingCustomerHomeIdList OPTIONAL,
    trackingCustomerLocList       TrackingCustomerLocList    OPTIONAL,
    trackingCustomerEquipment     TrackingCustomerEquipment  OPTIONAL,
...
}

TrackingCustomerLocation ::= [APPLICATION 369] SEQUENCE
{
    locationIdType                LocationIdType     OPTIONAL, -- *m.m.
    locationIdentifier            LocationIdentifier OPTIONAL, -- *m.m.
...
}

TrackingCustomerLocList ::= [APPLICATION 368] SEQUENCE OF TrackingCustomerLocation

TrackingFrequency ::= [APPLICATION 389] INTEGER

TrackingPeriod ::= [APPLICATION 388] INTEGER

TransactionAuthCode ::= [APPLICATION 342] AsciiString
 
TransactionDescriptionSupp ::= [APPLICATION 338] INTEGER
 
TransactionDetailDescription ::= [APPLICATION 339] AsciiString

TransactionIdentifier ::= [APPLICATION 341] AsciiString
 
TransactionShortDescription ::= [APPLICATION 340] AsciiString
 
TransactionStatus ::= [APPLICATION 303] INTEGER

TransferCutOffTimeStamp ::= [APPLICATION 227] DateTimeLong

TransparencyIndicator ::= [APPLICATION 228] INTEGER

UserProtocolIndicator ::= [APPLICATION 280] INTEGER

UtcTimeOffset ::= [APPLICATION 231] AsciiString --(SIZE(5))

UtcTimeOffsetCode ::= [APPLICATION 232] Code

UtcTimeOffsetInfo ::= [APPLICATION 233] SEQUENCE
{
    utcTimeOffsetCode   UtcTimeOffsetCode OPTIONAL, -- *m.m.
    utcTimeOffset       UtcTimeOffset     OPTIONAL, -- *m.m.
...
}

UtcTimeOffsetInfoList ::= [APPLICATION 234]  SEQUENCE OF UtcTimeOffsetInfo

VerticalAccuracyDelivered ::= [APPLICATION 393] INTEGER

VerticalAccuracyRequested ::= [APPLICATION 386] INTEGER


--
-- Tagged common data types
--

--
-- The AbsoluteAmount data type is used to 
-- encode absolute revenue amounts.
-- The accuracy of all absolute amount values is defined
-- by the value of TapDecimalPlaces within the group
-- AccountingInfo for the entire TAP batch.
-- Note, that only amounts greater than or equal to zero are allowed.
-- The decimal number representing the amount is 
-- derived from the encoded integer 
-- value by division by 10^TapDecimalPlaces.
-- for example for TapDecimalPlaces = 3 the following values
-- will be derived:
--       0   represents    0.000
--      12   represents    0.012
--    1234   represents    1.234
-- for TapDecimalPlaces = 5 the following values will be
-- derived:
--       0   represents    0.00000
--    1234   represents    0.01234
--  123456   represents    1.23456
-- This data type is used to encode (total) 
-- charges, (total) discount values and 
-- (total) tax values. 
-- 
AbsoluteAmount ::= INTEGER 

Bid ::=  AsciiString --(SIZE(5))

Code ::= INTEGER

--
-- Non-tagged common data types
--
--
-- Recommended common data types to be used for file encoding:
--
-- The following definitions should be used for TAP file creation instead of
-- the default specifications (OCTET STRING)
--
--    AsciiString ::= VisibleString
--
--    Currency ::= VisibleString
--
--    HexString ::= VisibleString
--
--    NumberString ::= NumericString
--
--    AsciiString contains visible ISO 646 characters.
--    Leading and trailing spaces must be discarded during processing.
--    An AsciiString cannot contain only spaces.

AsciiString ::= OCTET STRING

--
-- The BCDString data type (Binary Coded Decimal String) is used to represent
-- several digits from 0 through 9, a, b, c, d, e.
-- Two digits are encoded per octet.  The four leftmost bits of the octet represent
-- the first digit while the four remaining bits represent the following digit.  
-- A single f must be used as a filler when the total number of digits to be 
-- encoded is odd.
-- No other filler is allowed.

BCDString ::= OCTET STRING


--
-- The currency codes from ISO 4217
-- are used to identify a currency 
--
Currency ::= OCTET STRING

--
-- HexString contains ISO 646 characters from 0 through 9, A, B, C, D, E, F.
--

HexString ::= OCTET STRING

--
-- NumberString contains ISO 646 characters from 0 through 9.
--

NumberString ::= OCTET STRING


--
-- The PercentageRate data type is used to
-- encode percentage rates with an accuracy of 2 decimal places. 
-- This data type is used to encode discount rates.
-- The decimal number representing the percentage
-- rate is obtained by dividing the integer value by 100
-- Examples:
--
--     1500  represents  15.00 percent
--     1     represents   0.01 percent
--
PercentageRate ::= INTEGER 


-- END
END
}

1;
