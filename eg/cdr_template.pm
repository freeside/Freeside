package FS::cdr::cdr_template;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Example CDR format',
  'weight'        => 500,
  'header'        => 0,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv', #csv (default), fixedlength or xls
  'sep_char'      => ',',   #for csv, defaults to ,
  'disabled'      => 0,     #0 default, set to 1 to disable

  #listref of what to do with each field from the CDR, in order
  'import_fields' => [
    
    #place data directly in the specified field
    'freeside_cdr_fieldname',

    #subroutine reference
    sub { my($cdr, $field_data) = @_; 
          #do something to $field_data
          $cdr->fieldname($field_data);
        },

    #premade subref factory for date+time parsing, understands dates like:
    #  10/31/2007 08:57:24
    #  2007-10-31 08:57:24.113000000
    #  Mon Dec 15 11:38:34 2003
    _cdr_date_parser_maker('startddate'), #for example
    
    #premade subref factory for decimal minute parsing
    _cdr_min_parser_maker, #defaults to billsec and duration
    _cdr_min_parser_maker('fieldname'), #one field
    _cdr_min_parser_maker(['billsec', 'duration']), #listref for multiple fields

  ],

  #Parse::FixedLength field descriptions & lengths, for type=>'fixedlength' only
  'fixedlength_format' => [qw(
    Type:2:1:2
    Sequence:4:3:6
  )],

);

1;

__END__

list of freeside CDR fields, useful ones marked with *

       acctid - primary key
*[1]   calldate - Call timestamp (SQL timestamp)
       clid - Caller*ID with text
*      src - Caller*ID number / Source number
*      dst - Destination extension
       dcontext - Destination context
       channel - Channel used
       dstchannel - Destination channel if appropriate
       lastapp - Last application if appropriate
       lastdata - Last application data
*      startdate - Start of call (UNIX-style integer timestamp)
*      answerdate - Answer time of call (UNIX-style integer timestamp)
*      enddate - End time of call (UNIX-style integer timestamp)
*[2]   duration - Total time in system, in seconds
*[3]   billsec - Total time call is up, in seconds
*[4]   disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
       amaflags - What flags to use: BILL, IGNORE etc, specified on a per
       channel basis like accountcode.
*[5]   accountcode - CDR account number to use: account
       uniqueid - Unique channel identifier
       userfield - CDR user-defined field
       cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
*[6]   charged_party - Service number to be billed
       upstream_currency - Wholesale currency from upstream
*[7]   upstream_price - Wholesale price from upstream
       upstream_rateplanid - Upstream rate plan ID
       rated_price - Rated (or re-rated) price
       distance - km (need units field?)
       islocal - Local - 1, Non Local = 0
*[8]   calltypenum - Type of call - see FS::cdr_calltype
       description - Description (cdr_type 7&8 only) (used for
       cust_bill_pkg.itemdesc)
       quantity - Number of items (cdr_type 7&8 only)
*[9]   carrierid - Upstream Carrier ID (see FS::cdr_carrier)
       upstream_rateid - Upstream Rate ID
       svcnum - Link to customer service (see FS::cust_svc)
       freesidestatus - NULL, done (or something)

[1] Auto-populated from startdate if not present
[2] Auto-populated to enddate - startdate on insert if not specified
[3] Auto-populated to enddate - answerdate on insert if not specified
[4] Package options available to ignore calls without a specific disposition
[5] When using 'cdr-charged_party-accountcode' config
[6] Auto-populated from src (normal calls) or dst (toll free calls) if not present
[7] When using 'upstream_simple' rating method.
[8] Set to usage class classnum when using pre-rated CDRs and usage class-based
    taxation (local/intrastate/interstate/international)
[9] If doing settlement charging
