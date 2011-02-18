package FS::cdr::enswitch;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_min_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Enswitch',
  'weight'        => 515,
  'header'        => 2,
  'type'          => 'csv',
  'import_fields' => [
    'disposition',  #Status
    'startdate',    #Start, already a unix timestamp
    skip(2),        #Start date, Start time
    'enddate',      #End
    skip(4),        #End date, End time
                    #Calling customer, Calling type
    'src',          #Calling number
    'clid',         #Calling name
    skip(1),        #Called type
    'dst',          #Called number
    skip(23),       #Destination customer, Destination type
                    #Destination number
                    #Destination group ID, Destination group name,
                    #Inbound calling type, Inbound calling number,
                    #Inbound called type, Inbound called number,
                    #Inbound destination type, Inbound destination number,
                    #Outbound calling type, Outbound calling number,
                    #Outbound called type, Outbound called number,
                    #Outbound destination type, Outbound destination number,
                    #Internal calling type, Internal calling number,
                    #Internal called type, Internal called number,
                    #Internal destination type, Internal destination number
    'duration',     #Total seconds
    skip(1),        #Ring seconds
    'billsec',      #Billable seconds
    'upstream_price', #Cost
    'accountcode',  #Billing customer
    skip(3),        #Billing customer name, Billing type, Billing reference
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
