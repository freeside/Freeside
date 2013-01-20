package FS::pay_batch::nacha;

use strict;
use vars qw( %import_info %export_info $name $conf $entry_hash $DEBUG );
use Date::Format;
#use Time::Local 'timelocal';
#use FS::Conf;

$name = 'NACHA';

$DEBUG = 1;

%import_info = (
  #XXX stub finish me
  'filetype' => 'CSV',
  'fields' => [
  ],
  'hook' => sub {
    my $hash = shift;
  },
  'approved' => sub { 1 },
  'declined' => sub { 0 },
);

%export_info = (

  #optional
  init => sub {
    $conf = shift;
  },

  delimiter => '',


  header => sub {
    my( $pay_batch, $cust_pay_batch_arrayref ) = @_;

    $conf->config('batchconfig-nacha-destination') =~ /^\s*(\d{9})\s*$/
      or die 'illegal NACHA Destination';
    my $dest = $1;

    my $dest_name = $conf->config('batchconfig-nacha-destination_name');
    $dest_name = substr( $dest_name. (' 'x23), 0, 23);

    $conf->config('batchconfig-nacha-origin') =~ /^\s*(\d{10})\s*$/
      or die 'illegal NACHA Origin';
    my $origin = $1;

    my $company = $conf->config('company_name', $pay_batch->agentnum);
    $company = substr($company. (' 'x23), 0, 23);

    my $now = time;

    #haha don't want to break after a quarter million years of a batch a day
    #or 54 years for 5000 agent-virtualized hosted companies batching daily
    my $refcode = substr( (' 'x8). $pay_batch->batchnum, -8);

    #or only 25,000 years or 5.4 for 5000 companies :)
    #though they would probably want them numbered per company
    my $batchnum = substr( ('0'x7). $pay_batch->batchnum, -7);

    $entry_hash = 0;

    warn "building File & Batch Header Records\n" if $DEBUG;

    ##
    # File Header Record
    ##

    '1'.                      #Record Type Code
    '01'.                     #Priority Code
    ' '. $dest.               #Immediate Destination / 9-digit transit routing #
    $origin.                  #Immediate Origin / 10 digit company number
    time2str('%y%m%d', $now). #File Creation Date
    time2str('%H%M',   $now). #File Creation Time
    'A'.                 #XXX file ID modifier, mult. files in transit? [A-Z0-9]
    '094'.                    #94 character records
    '10'.                     #Blocking Factor
    '1'.                      #Format code
    $dest_name.               #Immediate Destination Name / 23 char bank name
    $company.                 #Immediate Origin Name / 23 char company name
    $refcode.                 #Reference Code (internal/optional)

    ###
    # Batch Header Record
    ###

    '5'.                     #Record Type Code
    '225'.                   #Service Class Code (220 credits only,
                             #                    200 mixed debits & credits)
    substr($company, 0, 16). #on cust. statements
    (' 'x20 ).               #20 char "company internal use if desired"
    $origin.                 #Company Identification (Immediate Origin)
    'PPD'. #others?
           #PPD "Prearranged Payments and Deposit entries" for consumer items
           #CCD (Cash Concentration and Disbursement)
           #CTX (Corporate Trade Exchange)
           #TEL (Telephone initiated entires)
           #WEB (Authorization received via the Internet)
    'InterntSvc'. #XXX from conf 10 char txn desc, printed on cust. statements

    #6 char "Descriptive date" printed on customer statements
    #XXX now? or use a separate post date?
    time2str('%y%m%d', $now).

    #6 char date transactions are to be posted
    #XXX now? or do we need a future banking day date like eft_canada trainwreck
    time2str('%y%m%d', $now).

    (' 'x3).                 #Settlement Date / Reserved
    '1'.                     #Originator Status Code
    substr($dest, 0, 8).     #Originating Financial Institution
    $batchnum                #Batch Number ("number batches sequentially")

  },

  'row' => sub {
    my( $cust_pay_batch, $pay_batch, $batchcount, $batchtotal ) = @_;

    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);

    # "Total of all positions 4-11 on each 6 record"
    $entry_hash += substr($aba,0,8); 

    my $cust_main = $cust_pay_batch->cust_main;
    my $cust_identifier = substr($cust_main->display_custnum. (' 'x15), 0, 15);

    #XXX paytype should actually be in the batch, but this will do for now
    #27 checking debit, 37 savings debit
    my $transaction_code = ( $cust_main->paytype =~ /savings/i ? '37' : '27' );

    my $cust_name = substr($cust_main->name. (' 'x22), 0, 22);

    #non-PPD transactions?  future

    warn "building PPD Record\n" if $DEBUG;

    ###
    # PPD Entry Detail Record
    ###

    '6'.                              #Record Type Code
    $transaction_code.                #Transaction Code
    $aba.                             #Receiving DFI Identification, check digit
    substr($account.(' 'x17), 0, 17). #DFI Account number (Left justify)
    sprintf('%010d', $cust_pay_batch->amount * 100). #Amount
    $cust_identifier.                 #Individual Identification Number, 15 char
    $cust_name.                       #Individual name (22-char)
    '  '.                             #2 char "company internal use if desired"
    '0'.                              #Addenda Record Indicator
    (' 'x15)                          #15 digit "bank will assign trace number"
                                      # (00000?)
  },

  'footer' => sub {
    my( $pay_batch, $batchcount, $batchtotal ) = @_;

    #Only use the final 10 positions in the entry
    $entry_hash = substr( '00'.$entry_hash, -10); 

    $conf->config('batchconfig-nacha-destination') =~ /^\s*(\d{9})\s*$/
      or die 'illegal NACHA Destination';
    my $dest = $1;

    $conf->config('batchconfig-nacha-origin') =~ /^\s*(\d{10})\s*$/
      or die 'illegal NACHA Origin';
    my $origin = $1;

    my $batchnum = substr( ('0'x7). $pay_batch->batchnum, -7);

    warn "building Batch and File Control Records\n" if $DEBUG;

    ###
    # Batch Control Record
    ###

    '8'.                          #Record Type Code
    '225'.                        #Service Class Code (220 credits only,
                                  #                    200 mixed debits&credits)
    sprintf('%06d', $batchcount). #Entry / Addenda Count
    $entry_hash.
    sprintf('%012d', $batchtotal * 100). #Debit total
    '000000000000'.               #Credit total
    $origin.                      #Company Identification (Immediate Origin)
    (' 'x19).                     #Message Authentication Code (19 char blank)
    (' 'x6).                      #Federal Reserve Use (6 char blank)
    substr($dest, 0, 8).          #Originating Financial Institution
    $batchnum.                    #Batch Number ("number batches sequentially")

    ###
    # File Control Record
    ###

    '9'.                                 #Record Type Code
    '000001'.                            #Batch Counter (# of batch header recs)
    sprintf('%06d', $batchcount + 4).    #num of physical blocks on the file..?
    sprintf('%08d', $batchcount).        #total # of entry detail and addenda
    $entry_hash.
    sprintf('%012d', $batchtotal * 100). #Debit total
    '000000000000'.                      #Credit total
    ( ' 'x39 )                           #Reserved / blank

  },

);

1;

