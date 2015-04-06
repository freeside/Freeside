package FS::cdr::enswitch;
use base qw( FS::cdr );

use strict;
use vars qw( %info $tmp_mon $tmp_mday $tmp_year );
use FS::Record qw( qsearchs );
use FS::cdr_type;

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
    'dcontext',     #Called type
    'dst',          #Called number
    skip(26),       #Destination customer, Destination type
                    #Destination number
                    #Destination group ID, Destination group name,
    		    #Inbound calling type,
    		    #Inbound calling number,
                    #Inbound called type,
    		    #Inbound called number,
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
    skip(2),        #Cost
    	            #Cost including taxes
    'accountcode',  #Billing customer
    skip(3),        #Billing customer name, Billing type, Billing reference
  ],
);

sub skip { map {''} (1..$_[0]) }

#create CDR types with names matching in_calling_type valuesj - 'none'
# (without the quotes) for blank
our %cdr_type = ();
sub in_calling_type {
  my ($record, $data) = @_;

  $data ||= 'none';

  my $cdr_type = exists($cdr_type{$data})
                   ? $cdr_type{$data}
                   : qsearchs('cdr_type', { 'cdrtypename' => $data } );

  $cdr_type{$data} = $cdr_type;

  $record->set('in_calling_type', $data); #for below
  $record->set('cdrtypenum', $cdr_type->cdrtypenum) if $cdr_type;

}

1;
