package FS::cdr::cisco;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );
use Date:Parse;

%info = (
  'name'          => 'Cisco Unified Call Manager',
  'weight'        => 160,
  'header'        => 2,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv', #csv (default), fixedlength or xls
  'sep_char'      => ',',   #for csv, defaults to ,
  'disabled'      => 0,     #0 default, set to 1 to disable

  'import_fields' => [

					     skip(2),   #cdrRecordType
							#globalCallID_callManagerId
					      'clid',	#globalCallID_callId	
					     skip(1),	#origLegCallIdentifier	
                sub { my ($cdr, $calldate) = @_;
                        $cdr->set('startdate', $calldate);
                        $calldate = str2time($calldate);
                        $cdr->set('calldate', $calldate);
                                                  },    #dateTimeOrigination
					     skip(3),   #origNodeId	
							#origSpan
							#origIpAddr	
					       'src',	#callingPartyNumber	
					    skip(20),	#callingPartyUnicodeLoginUserID	
							#origCause_location	
							#origCause_value	
							#origPrecedenceLevel	
							#origMediaTransportAddress_IP	
							#origMediaTransportAddress_Port	
							#origMediaCap_payloadCapability
							#origMediaCap_maxFramesPerPacket
							#origMediaCap_g723BitRate	
							#origVideoCap_Codec	
							#origVideoCap_Bandwidth	
							#origVideoCap_Resolution	
							#origVideoTransportAddress_IP	
							#origVideoTransportAddress_Port	
							#origRSVPAudioStat	
							#origRSVPVideoStat	
							#destLegIdentifier	
							#destNodeId	
							#destSpan	
							#destIpAddr	
					      'dst',	#originalCalledPartyNumber	
					   skip(17),	#finalCalledPartyNumber	
							#finalCalledPartyUnicodeLoginUserID
							#destCause_location	
							#destCause_value
							#destPrecedenceLevel
							#destMediaTransportAddress_IP
							#destMediaTransportAddress_Port	
							#destMediaCap_payloadCapability	
							#destMediaCap_maxFramesPerPacket
							#destMediaCap_g723BitRate
							#destVideoCap_Codec
							#destVideoCap_Bandwidth
							#destVideoCap_Resolution
							#destVideoTransportAddress_IP
							#destVideoTransportAddress_Port
							#destRSVPAudioStat
							#destRSVPVideoStat
					'answerdate',	#dateTimeConnect	
		   			   'enddate',	#dateTimeDisconnect
					skip(6),	#lastRedirectDn	
							#pkid
							#originalCalledPartyNumberPartition	
							#callingPartyNumberPartition	
							#finalCalledPartyNumberPartition
							#lastRedirectDnPartition
				       'billsec',	#duration
					skip(48),	#origDeviceName
							#destDeviceName
							#origCallTerminationOnBehalfOf
							#destCallTerminationOnBehalfOf
							#origCalledPartyRedirectOnBehalfOf
							#lastRedirectRedirectOnBehalfOf	
							#origCalledPartyRedirectReason
							#lastRedirectRedirectReason
							#destConversationId
							#globalCallId_ClusterID
							#joinOnBehalfOf
							#comment	
							#authCodeDescription
							#authorizationLevel	
							#clientMatterCode
							#origDTMFMethod
							#destDTMFMethod	
							#callSecuredStatus
							#origConversationId
							#origMediaCap_Bandwidth
							#destMediaCap_Bandwidth	
							#authorizationCodeValue
							#outpulsedCallingPartyNumber
							#outpulsedCalledPartyNumber
							#origIpv4v6Addr	
							#destIpv4v6Addr	
							#origVideoCap_Codec_Channel2
							#origVideoCap_Bandwidth_Channel2
							#origVideoCap_Resolution_Channel2
							#origVideoTransportAddress_IP_Channel2	
							#origVideoTransportAddress_Port_Channel2
							#origVideoChannel_Role_Channel2
							#destVideoCap_Codec_Channel2
							#destVideoCap_Bandwidth_Channel2
							#destVideoCap_Resolution_Channel2
							#destVideoTransportAddress_IP_Channel2
							#destVideoTransportAddress_Port_Channel2
							#destVideoChannel_Role_Channel2
							#IncomingProtocolID
							#IncomingProtocolCallRef
							#OutgoingProtocolID
							#OutgoingProtocolCallRef	
							#currentRoutingReason
							#origRoutingReason
							#lastRedirectingRoutingReason
							#huntPilotPartition
							#huntPilotDN
							#calledPartyPatternUsage
  ],

);




sub skip { map {''} (1..$_[0]) }

1;

