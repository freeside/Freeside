package FS::cdr::u4;

use strict;
use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

# About the ANI/DNIS/*Number columns:
# For inbound calls, ANI appears to be the true source number.
# Usually ANI = TermNumber in that case.  (Case 1a.)
# In a few inbound CDRs, ANI = OrigNumber, the BillToNumber is also 
# the DialedNumber and DNIS (and always an 800 number), and the TermNumber 
# is a different number.  (Case 2; rare.)
#
# For outbound calls, DNIS is always empty.  The TermNumber appears to
# be the true destination.  The DialedNumber may be empty (Case 1b), or
# equal the TermNumber (Case 3), or be a different number (Case 4; this 
# probably shows routing to a different destination).
#
# How we are handling them:
# Case 1a (inbound): src = ANI, dst = BillToNumber
# Case 1b (outbound): src = BillToNumber, dst = ANI
# Case 2: src = ANI, dst = DialedNumber, dst_term = TermNumber
# Case 3: src = BillToNumber, dst = DialedNumber
# Case 4: src = BillToNumber, dst = DialedNumber, dst_term = TermNumber

%info = (
  'name'          => 'U4',
  'weight'        => 490,
  'type'          => 'fixedlength',
  'fixedlength_format' => [qw(
    CDRType:3:1:3
    MasterAccountID:12:4:15
    SubAccountID:12:16:27
    BillToNumber:18:28:45
    AccountCode:12:46:57
    CallDateStartTime:14:58:71
    TimeOfDay:1:72:72
    CalculatedSeconds:12:73:84
    City:30:85:114
    State:2:115:116
    Country:40:117:156
    Charges:21:157:177
    CallDirection:1:178:178
    CallIndicator:1:179:179
    ReportIndicator:1:180:180
    ANI:10:181:190
    DNIS:10:191:200
    PIN:16:201:216
    OrigNumber:10:217:226
    TermNumber:10:227:236
    DialedNumber:18:237:254
    DisplayNumber:18:255:272
    RecordSource:1:273:273
    LECInfoDigits:2:274:275
    OrigNPA:4:276:279
    OrigNXX:5:280:284
    OrigLATA:3:285:287
    OrigZone:1:288:288
    OrigCircuit:12:289:300
    OrigTrunkGroupCLLI:12:301:312
    TermNPA:4:313:316
    TermNXX:5:317:321
    TermLATA:3:322:324
    TermZone:1:325:325
    TermCircuit:12:326:337
    TermTrunkGroupCLLI:12:338:349
    TermOCN:5:350:354
  )],
  # at least that's how they're defined in the spec we have.
  # the real CDRs have several differences.
  'import_fields' => [
    '',               #CDRType (for now always 'V')
    '',               #MasterAccountID
    '',               #SubAccountID
    'charged_party',  #BillToNumber
    'accountcode',    #AccountCode
    _cdr_date_parser_maker('startdate'),
                      #CallDateTime
    '',               #TimeOfDay (always 'S')
    sub {             #CalculatedSeconds
      my($cdr, $sec) = @_;
      $cdr->duration($sec);
      $cdr->billsec($sec);
    },
    '',               #City
    '',               #State
    '',               #Country
    'upstream_price', #Charges
    sub {             #CallDirection
      my ($cdr, $dir) = @_;
      $cdr->set('direction', $dir);
      if ( $dir eq 'O' ) {
        $cdr->set('src', $cdr->charged_party);
      } elsif ( $dir eq 'I' ) {
        $cdr->set('dst', $cdr->charged_party);
      }
    },
    '',               #CallIndicator  #calltype?
    '',               #ReportIndicator
    sub {             #ANI
      # For inbound calls, this is the source.
      # For outbound calls it's sometimes the destination but TermNumber 
      # is more reliable.
      my ($cdr, $number) = @_;
      if ( $cdr->direction eq 'I' ) {
        $cdr->set('src', $number);
      }
    },
    '',               #DNIS
    '',               #PIN
    '',               #OrigNumber
    sub {             #TermNumber
      # For outbound calls, this is the terminal destination (after call 
      # routing).  It's sometimes also the dialed destination (Case 1b and 3).
      my ($cdr, $number) = @_;
      if ( $cdr->direction eq 'O' ) {
        $cdr->set('dst_term', $number);
        $cdr->set('dst', $number); # change this later if Case 4
      }
    },
    sub {             #DialedNumber
      my ($cdr, $number) = @_;
      # For outbound calls, this is the destination before any call routing,
      # and should be used for billing.  Except when it's null; then use 
      # the TermNumber.
      if ( $cdr->direction eq 'O' and $number =~ /\d/ ) {
        # Case 4
        $cdr->set('dst', $number);
      }
    },

    '',               #DisplayNumber
    '',               #RecordSource
    '',               #LECInfoDigits
    ('') x 13,
  ],
);

# Case 1a (inbound): src = ANI, dst = BillToNumber
# Case 1b (outbound): src = BillToNumber, dst = TermNumber
# Case 2: src = ANI, dst = DialedNumber, dst_term = TermNumber
# Case 3: src = BillToNumber, dst = TermNumber
# Case 4: src = BillToNumber, dst = DialedNumber, dst_term = TermNumber

1;
