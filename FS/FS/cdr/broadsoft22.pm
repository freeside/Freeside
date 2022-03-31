package FS::cdr::broadsoft22;

=head1 NAME

FS::cdr::broadsoft22 - CDR parse module for Broadsoft R22.0

=head1 DESCRIPTION

Ref: BW-AccountingCDRInterfaceSpec-R22.pdf

=cut

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  name     => 'Broadsoft R22',
  weight   => 500,
  header   => 1,
  type     => 'csv',
  sep_char => ',',
  disabled => 0,

  import_fields => [

    # 1: recordId
    # 2: serviceProvider
    skip(2),

    # 3: type
    sub {
      my ( $cdr, $data, $conf, $param ) = @_;
      $param->{skiprow} = 1
        if lc($data) ne 'normal';
      '';
    },

    # 4: userNumber
    # 5: groupNumber
    skip(2),

    # 6: direction
    'dcontext',

    # 7: callingNumber
    trim('src'),

    # 8: callingPresentationINdicator
    skip(1),

    # 9: calledNumber
    trim('dst'),

    # 10: startTime
    _cdr_date_parser_maker('startdate'),

    # 11: userTimeZone
    skip(1),

    # 12: answerIndicator
    sub {
      my( $cdr, $data ) = @_;
      $cdr->disposition( lc($data) eq 'yes' ? 'ANSWERED' : 'NO ANSWER');
    },

    # 13: answerTime
    _cdr_date_parser_maker('answerdate'),

    # 14: releaseTime
    _cdr_date_parser_maker('enddate'),

    # 15: terminationCause
    # 16: networkType
    # 17: carrierIdentificationCode
    # 18: dialedDigits
    # 19: callCategory
    # 20: networkCallType
    # 21: networkTranslatedNumber
    # 22: networkTranslatedGroup
    # 23: releasingParty
    # 24: route
    skip(10),

    # 25: networkCallID
    'sipcallid',

    # 26: codedc
    # 27: accessDeviceAddress
    # 28: accessCallID
    # 29: spare
    # 30: failoverCorrelationId
    # 31: spare
    # 32: group
    # 33: department
    skip(8),

    # 34: accountCode
    sub {
      my( $cdr, $data ) = @_;
      $cdr->set(
        'accountcode',
        $cdr->is_tollfree ? substr( $cdr->dst, 0, 32 ) : $data
      );
    },

    # 35: authorizationCode
    # 36: originalCalledNumber
    # 37: originalCalledPresentationIndicator
    # 38: originalCalledReason
    # 39: redirectingNumber
    # 40: redirectingPresentationIndicator
    # 41: redirectingReason
    # 42: chargeIndicator
    # 43: typeOfNetwork
    # 44: voicePortalCalling.invocationTime
    # 45: localCallId
    # 46: remoteCallId
    # 47: callingPartyCategory
    #
    # Also... cols 48 - 448 see Broadsoft documentation
    skip(111), #35-145 inclusive

    # 146: chargedNumber
    'charged_party',

  ],

);

sub trim {
  my $fieldname = shift;
  return sub {
    my($cdr, $data) = @_;
    $data =~ s/^\+1//;
    $cdr->$fieldname($data);
    ''
  }
}

sub skip {
  map { undef } (1..$_[0]);
}

1;

__END__

list of freeside CDR fields, useful ones marked with *

           acctid - primary key
    *[1]   calldate - Call timestamp (SQL timestamp)
           clid - Caller*ID with text
7   *      src - Caller*ID number / Source number
9   *      dst - Destination extension
           dcontext - Destination context
           channel - Channel used
           dstchannel - Destination channel if appropriate
           lastapp - Last application if appropriate
           lastdata - Last application data
10  *      startdate - Start of call (UNIX-style integer timestamp)
13         answerdate - Answer time of call (UNIX-style integer timestamp)
14  *      enddate - End time of call (UNIX-style integer timestamp)
    *      duration - Total time in system, in seconds
    *      billsec - Total time call is up, in seconds
12  *[2]   disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
           amaflags - What flags to use: BILL, IGNORE etc, specified on a per
           channel basis like accountcode.
4   *[3]   accountcode - CDR account number to use: account
           uniqueid - Unique channel identifier
           userfield - CDR user-defined field
           cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
    *[4]   charged_party - Service number to be billed
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
           carrierid - Upstream Carrier ID (see FS::cdr_carrier)
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
