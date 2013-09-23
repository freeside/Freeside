package FS::cdr::voip_innovations;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'VoIP Innovations',
  'weight'        => 540,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => ';',

  'import_fields' => [
    # CallType
    sub { my($cdr, $type) = @_;
          # DNIS and ANI are the same columns regardless of direction,
          # so all we need to assign is the IP address
          if ($type =~ /^term/i) {
            $cdr->dst_ip_addr( $cdr->get('ipaddr') );
          } else {
            $cdr->src_ip_addr( $cdr->get('ipaddr') );
          }
          # also strip the leading '1' or '+1' from src/dst
          foreach (qw(src dst)) {
            my $num = $cdr->get($_);
            $num =~ s/^\+?1//;
            $cdr->set($_, $num);
          }
        },
    # StartTime
    _cdr_date_parser_maker('startdate'),
    # StopTime
    _cdr_date_parser_maker('enddate'),
    # CallDuration
    sub { my($cdr, $duration) = @_;
          $cdr->duration(sprintf('%.0f',$duration));
        },
    # BillDuration (granularized)
    sub { my($cdr, $billsec) = @_;
          $cdr->billsec(sprintf('%.0f',$billsec));
        },
    # CallMinimum, CallIncrement (used to granularize BillDuration)
    '', '',
    # BasePrice
    '',
    # CallPrice
    'upstream_price',
    # TransactionId (seems not to be meaningful to us)
    '',
    # CustomerIP
    'ipaddr', # will go to src or dst addr, depending
    # ANI
    'src',
    # ANIState
    '', # would be really useful for classifying inter/intrastate calls, 
        # except we don't use it
    # DNIS
    'dst',
    # LRN (Local Routing Number of the destination)
    '',
    # DNISState, DNISLATA, DNISOCN
    '', '', '',
    # OrigTier, TermRateDeck
    '', '', # these are upstream rate plans, but they're not numeric
  ],
);

1;
