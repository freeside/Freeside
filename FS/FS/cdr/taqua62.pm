package FS::cdr::taqua62;

use strict;
use vars qw(@ISA %info $da_rewrite);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Taqua v6.2',
  'weight'        => 131,
  'header'        => 1,
  'import_fields' => [

    #0
    '', #Key 
    '', #InsertTime, irrelevant
    #RecordType
    sub {
      my($cdr, $field, $conf, $hashref) = @_;
      $hashref->{skiprow} = 1
        unless ($field == 0 && $cdr->disposition == 100       )  #regular CDR
            || ($field == 1 && $cdr->lastapp     eq 'acctcode'); #accountcode
      $cdr->cdrtypenum($field);
    },

    '',       #RecordVersion
    '',       #OrigShelfNumber
    '',       #OrigCardNumber
    '',       #OrigCircuit
    '',       #OrigCircuitType
    'uniqueid',                           #SequenceNumber
    'sessionnum',                         #SessionNumber
    #10
    'src',                                #CallingPartyNumber
    #CalledPartyNumber
    sub {
      my( $cdr, $field, $conf ) = @_;
      if ( $cdr->calltypenum == 6 && $cdr->cdrtypenum == 0 ) {
        $cdr->dst("+$field");
      } else {
        $cdr->dst($field);
      }
    },

    _cdr_date_parser_maker('startdate', 'gmt' => 1),  #CallArrivalTime
    _cdr_date_parser_maker('enddate', 'gmt' => 1),    #CallCompletionTime

    #Disposition
    #sub { my($cdr, $d ) = @_; $cdr->disposition( $disposition{$d}): },
    'disposition',
                                          #  -1 => '',
                                          #   0 => '',
                                          # 100 => '', #regular cdr
                                          # 101 => '',
                                          # 102 => '',
                                          # 103 => '',
                                          # 104 => '',
                                          # 105 => '',
                                          # 201 => '',
                                          # 203 => '',
                                          # 204 => '',

    _cdr_date_parser_maker('answerdate', 'gmt' => 1), #DispositionTime
    '',       #TCAP
    '',       #OutboundCarrierConnectTime
    '',       #OutboundCarrierDisconnectTime

    #TermTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'dstchannel',                         #TermTrunkGroup

    #20

    '',       #TermShelfNumber
    '',       #TermCardNumber
    '',       #TermCircuit
    '',       #TermCircuitType
    'carrierid',                          #OutboundCarrierId

    #BillingNumber
    #'charged_party',                      
    sub {
      my( $cdr, $field, $conf ) = @_;

      #could be more efficient for the no config case, if anyone ever needs that
      $da_rewrite ||= $conf->config('cdr-taqua-da_rewrite');

      if ( $da_rewrite && $field =~ /\d/ ) {
        my $rewrite = $da_rewrite;
        $rewrite =~ s/\s//g;
        my @rewrite = split(',', $conf->config('cdr-taqua-da_rewrite') );
        if ( grep { $field eq $_ } @rewrite ) {
          $cdr->charged_party( $cdr->src() );
          $cdr->calltypenum(12);
          return;
        }
      }
      if ( $cdr->is_tollfree ) {        # thankfully this is already available
        $cdr->charged_party($cdr->dst); # and this
      } else {
        $cdr->charged_party($field);
      }
    },

    'subscriber',                         #SubscriberName
    'lastapp',                            #ServiceName
    '',       #some weirdness #ChargeTime
    'lastdata',                           #ServiceInformation

    #30

    '',       #FacilityInfo
    '',             #all 1900-01-01 0#CallTraceTime
    '',             #all-1#UniqueIndicator
    '',             #all-1#PresentationIndicator
    '',             #empty#Pin
    'calltypenum',                        #CallType

    #nothing below is used by QIS...

    '',           #Balt/empty #OrigRateCenter
    '',           #Balt/empty #TermRateCenter

    #OrigTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'channel',                            #OrigTrunkGroup
    'userfield',                                #empty#UserDefined

    #40

    '',             #empty#PseudoDestinationNumber
    '',             #all-1#PseudoCarrierCode
    '',             #empty#PseudoANI
    '',             #all-1#PseudoFacilityInfo
    '',       #OrigDialedDigits
    '',             #all-1#OrigOutboundCarrier
    '',       #IncomingCarrierID
    'dcontext',                           #JurisdictionInfo
    '',       #OrigDestDigits
    '',             #empty#AMALineNumber

    #50

    '',             #empty#AMAslpID
    '',             #empty#AMADigitsDialedWC
    '',       #OpxOffHook
    '',       #OpxOnHook
    '',       #OrigCalledNumber
    '',       #RedirectingNumber
    '',       #RouteAttempts
    '',       #OrigMGCPTerm
    '',       #TermMGCPTerm
    '',       #ReasonCode

    #60
    
    '',       #OrigIPCallID
    '',       #ESAIPTrunkGroup
    '',       #ESAReason
    '',       #BearerlessCall
    '',       #oCodec
    '',       #tCodec
    '',       #OrigTrunkGroupNumber
    '',       #TermTrunkGroupNumber
    '',       #TermRecord
    '',       #OrigRoutingIndicator

    #70

    '',       #TermRoutingIndicator

  ],
);

1;
