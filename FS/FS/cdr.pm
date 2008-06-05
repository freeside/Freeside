package FS::cdr;

use strict;
use vars qw( @ISA );
use Date::Parse;
use Date::Format;
use Time::Local;
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::cdr_type;
use FS::cdr_calltype;
use FS::cdr_carrier;
use FS::cdr_upstream_rate;

@ISA = qw(FS::Record);

=head1 NAME

FS::cdr - Object methods for cdr records

=head1 SYNOPSIS

  use FS::cdr;

  $record = new FS::cdr \%hash;
  $record = new FS::cdr { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr object represents an Call Data Record, typically from a telephony
system or provider of some sort.  FS::cdr inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item acctid - primary key

=item calldate - Call timestamp (SQL timestamp)

=item clid - Caller*ID with text

=item src - Caller*ID number / Source number

=item dst - Destination extension

=item dcontext - Destination context

=item channel - Channel used

=item dstchannel - Destination channel if appropriate

=item lastapp - Last application if appropriate

=item lastdata - Last application data

=item startdate - Start of call (UNIX-style integer timestamp)

=item answerdate - Answer time of call (UNIX-style integer timestamp)

=item enddate - End time of call (UNIX-style integer timestamp)

=item duration - Total time in system, in seconds

=item billsec - Total time call is up, in seconds

=item disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY 

=item amaflags - What flags to use: BILL, IGNORE etc, specified on a per channel basis like accountcode. 

=cut

  #ignore the "omit" and "documentation" AMAs??
  #AMA = Automated Message Accounting. 
  #default: Sets the system default. 
  #omit: Do not record calls. 
  #billing: Mark the entry for billing 
  #documentation: Mark the entry for documentation.

=item accountcode - CDR account number to use: account

=item uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)

=item userfield - CDR user-defined field

=item cdr_type - CDR type - see L<FS::cdr_type> (Usage = 1, S&E = 7, OC&C = 8)

=item charged_party - Service number to be billed

=item upstream_currency - Wholesale currency from upstream

=item upstream_price - Wholesale price from upstream

=item upstream_rateplanid - Upstream rate plan ID

=item rated_price - Rated (or re-rated) price

=item distance - km (need units field?)

=item islocal - Local - 1, Non Local = 0

=item calltypenum - Type of call - see L<FS::cdr_calltype>

=item description - Description (cdr_type 7&8 only) (used for cust_bill_pkg.itemdesc)

=item quantity - Number of items (cdr_type 7&8 only)

=item carrierid - Upstream Carrier ID (see L<FS::cdr_carrier>) 

=cut

#Telstra =1, Optus = 2, RSL COM = 3

=item upstream_rateid - Upstream Rate ID

=item svcnum - Link to customer service (see L<FS::cust_svc>)

=item freesidestatus - NULL, done (or something)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new CDR.  To add the CDR to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid CDR.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

Note: Unlike most types of records, we don't want to "reject" a CDR and we want
to process them as quickly as possible, so we allow the database to check most
of the data.

=cut

sub check {
  my $self = shift;

# we don't want to "reject" a CDR like other sorts of input...
#  my $error = 
#    $self->ut_numbern('acctid')
##    || $self->ut_('calldate')
#    || $self->ut_text('clid')
#    || $self->ut_text('src')
#    || $self->ut_text('dst')
#    || $self->ut_text('dcontext')
#    || $self->ut_text('channel')
#    || $self->ut_text('dstchannel')
#    || $self->ut_text('lastapp')
#    || $self->ut_text('lastdata')
#    || $self->ut_numbern('startdate')
#    || $self->ut_numbern('answerdate')
#    || $self->ut_numbern('enddate')
#    || $self->ut_number('duration')
#    || $self->ut_number('billsec')
#    || $self->ut_text('disposition')
#    || $self->ut_number('amaflags')
#    || $self->ut_text('accountcode')
#    || $self->ut_text('uniqueid')
#    || $self->ut_text('userfield')
#    || $self->ut_numbern('cdrtypenum')
#    || $self->ut_textn('charged_party')
##    || $self->ut_n('upstream_currency')
##    || $self->ut_n('upstream_price')
#    || $self->ut_numbern('upstream_rateplanid')
##    || $self->ut_n('distance')
#    || $self->ut_numbern('islocal')
#    || $self->ut_numbern('calltypenum')
#    || $self->ut_textn('description')
#    || $self->ut_numbern('quantity')
#    || $self->ut_numbern('carrierid')
#    || $self->ut_numbern('upstream_rateid')
#    || $self->ut_numbern('svcnum')
#    || $self->ut_textn('freesidestatus')
#  ;
#  return $error if $error;

  $self->calldate( $self->startdate_sql )
    if !$self->calldate && $self->startdate;

  unless ( $self->charged_party ) {
    if ( $self->dst =~ /^(\+?1)?8[02-8]{2}/ ) {
      $self->charged_party($self->dst);
    } else {
      $self->charged_party($self->src);
    }
  }

  #check the foreign keys even?
  #do we want to outright *reject* the CDR?
  my $error =
       $self->ut_numbern('acctid')

    #Usage = 1, S&E = 7, OC&C = 8
    || $self->ut_foreign_keyn('cdrtypenum',  'cdr_type',     'cdrtypenum' )

    #the big list in appendix 2
    || $self->ut_foreign_keyn('calltypenum', 'cdr_calltype', 'calltypenum' )

    # Telstra =1, Optus = 2, RSL COM = 3
    || $self->ut_foreign_keyn('carrierid', 'cdr_carrier', 'carrierid' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item set_status_and_rated_price STATUS [ RATED_PRICE ]

Sets the status to the provided string.  If there is an error, returns the
error, otherwise returns false.

=cut

sub set_status_and_rated_price {
  my($self, $status, $rated_price) = @_;
  $self->freesidestatus($status);
  $self->rated_price($rated_price);
  $self->replace();
}

=item calldate_unix 

Parses the calldate in SQL string format and returns a UNIX timestamp.

=cut

sub calldate_unix {
  str2time(shift->calldate);
}

=item startdate_sql

Parses the startdate in UNIX timestamp format and returns a string in SQL
format.

=cut

sub startdate_sql {
  my($sec,$min,$hour,$mday,$mon,$year) = localtime(shift->startdate);
  $mon++;
  $year += 1900;
  "$year-$mon-$mday $hour:$min:$sec";
}

=item cdr_carrier

Returns the FS::cdr_carrier object associated with this CDR, or false if no
carrierid is defined.

=cut

my %carrier_cache = ();

sub cdr_carrier {
  my $self = shift;
  return '' unless $self->carrierid;
  $carrier_cache{$self->carrierid} ||=
    qsearchs('cdr_carrier', { 'carrierid' => $self->carrierid } );
}

=item carriername 

Returns the carrier name (see L<FS::cdr_carrier>), or the empty string if
no FS::cdr_carrier object is assocated with this CDR.

=cut

sub carriername {
  my $self = shift;
  my $cdr_carrier = $self->cdr_carrier;
  $cdr_carrier ? $cdr_carrier->carriername : '';
}

=item cdr_calltype

Returns the FS::cdr_calltype object associated with this CDR, or false if no
calltypenum is defined.

=cut

my %calltype_cache = ();

sub cdr_calltype {
  my $self = shift;
  return '' unless $self->calltypenum;
  $calltype_cache{$self->calltypenum} ||=
    qsearchs('cdr_calltype', { 'calltypenum' => $self->calltypenum } );
}

=item calltypename 

Returns the call type name (see L<FS::cdr_calltype>), or the empty string if
no FS::cdr_calltype object is assocated with this CDR.

=cut

sub calltypename {
  my $self = shift;
  my $cdr_calltype = $self->cdr_calltype;
  $cdr_calltype ? $cdr_calltype->calltypename : '';
}

=item cdr_upstream_rate

Returns the upstream rate mapping (see L<FS::cdr_upstream_rate>), or the empty
string if no FS::cdr_upstream_rate object is associated with this CDR.

=cut

sub cdr_upstream_rate {
  my $self = shift;
  return '' unless $self->upstream_rateid;
  qsearchs('cdr_upstream_rate', { 'upstream_rateid' => $self->upstream_rateid })
    or '';
}

=item _convergent_format COLUMN [ COUNTRYCODE ]

Returns the number in COLUMN formatted as follows:

If the country code does not match COUNTRYCODE (default "61"), it is returned
unchanged.

If the country code does match COUNTRYCODE (default "61"), it is removed.  In
addiiton, "0" is prepended unless the number starts with 13, 18 or 19. (???)

=cut

sub _convergent_format {
  my( $self, $field ) = ( shift, shift );
  my $countrycode = scalar(@_) ? shift : '61'; #+61 = australia
  #my $number = $self->$field();
  my $number = $self->get($field);
  #if ( $number =~ s/^(\+|011)$countrycode// ) {
  if ( $number =~ s/^\+$countrycode// ) {
    $number = "0$number"
      unless $number =~ /^1[389]/; #???
  }
  $number;
}

=item downstream_csv [ OPTION => VALUE, ... ]

=cut

my %export_names = (
  'convergent'      => {},
  'voxlinesystems'  => { 'name'           => 'VoxLineSystems',
                         'invoice_header' =>
                           "Date,Time,Name,Destination,Duration,Price",
                       },
  'voxlinesystems2' => { 'name'           => 'VoxLineSystems with source',
                         'invoice_header' =>
                           "Date,Time,Name,Destination,Called From,Duration,Price",
                       },
);

my %export_formats = (
  'convergent' => [
    'carriername', #CARRIER
    sub { shift->_convergent_format('src') }, #SERVICE_NUMBER
    sub { shift->_convergent_format('charged_party') }, #CHARGED_NUMBER
    sub { time2str('%Y-%m-%d', shift->calldate_unix ) }, #DATE
    sub { time2str('%T',       shift->calldate_unix ) }, #TIME
    'billsec', #'duration', #DURATION
    sub { shift->_convergent_format('dst') }, #NUMBER_DIALED
    '', #XXX add (from prefixes in most recent email) #FROM_DESC
    '', #XXX add (from prefixes in most recent email) #TO_DESC
    'calltypename', #CLASS_CODE
    'rated_price', #PRICE
    sub { shift->rated_price ? 'Y' : 'N' }, #RATED
    '', #OTHER_INFO
  ],
  'voxlinesystems' => [
    sub { time2str('%D', shift->calldate_unix ) },   #DATE
    sub { time2str('%r', shift->calldate_unix ) },   #TIME
    'userfield',                                     #USER
    'dst',                                           #NUMBER_DIALED
    sub { sprintf('%.2fm', shift->billsec / 60 ) },  #DURATION
    sub { sprintf('%.3f', shift->upstream_price ) }, #PRICE
  ],
  'voxlinesystems2' => [
    sub { time2str('%D', shift->calldate_unix ) },   #DATE
    sub { time2str('%T', shift->calldate_unix ) },   #TIME
    'userfield',                                     #USER
    'dst',                                           #NUMBER_DIALED
    'src',                                           #called from
    sub { sprintf('%.2fm', shift->billsec / 60 ) },  #DURATION
    sub { sprintf('%.3f', shift->upstream_price ) }, #PRICE
  ],
);

sub downstream_csv {
  my( $self, %opt ) = @_;

  my $format = $opt{'format'}; # 'convergent';
  return "Unknown format $format" unless exists $export_formats{$format};

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  my @columns =
    map {
          ref($_) ? &{$_}($self) : $self->$_();
        }
    @{ $export_formats{$format} };

  my $status = $csv->combine(@columns);
  die "FS::CDR: error combining ". $csv->error_input(). "into downstream CSV"
    unless $status;

  $csv->string;

}

=back

=head1 CLASS METHODS

=over 4

=item invoice_formats

Returns an ordered list of key value pairs containing invoice format names
as keys (for use with part_pkg::voip_cdr) and "pretty" format names as values.

=cut

sub invoice_formats {
  map { ($_ => $export_names{$_}->{'name'}) }
    grep { $export_names{$_}->{'invoice_header'} }
    keys %export_names;
}

=item invoice_header FORMAT

Returns a scalar containing the CSV column header for invoice format FORMAT.

=cut

sub invoice_header {
  my $format = shift;
  $export_names{$format}->{'invoice_header'};
}

=item import_formats

Returns an ordered list of key value pairs containing import format names
as keys (for use with batch_import) and "pretty" format names as values.

=cut

sub import_formats {
  (
    'asterisk'       => 'Asterisk',
    'taqua'          => 'Taqua',
    'unitel'         => 'Unitel/RSLCOM',
    'voxlinesystems' => 'VoxLineSystems',  #XXX? get the actual vendor name
    'simple'         => 'Simple',
  );
}

my($tmp_mday, $tmp_mon, $tmp_year);

sub _cdr_date_parser_maker {
  my $field = shift;
  return sub {
    my( $cdr, $date ) = @_;
    #$cdr->$field( _cdr_date_parse($date) );
    eval { $cdr->$field( _cdr_date_parse($date) ); };
    die "error parsing date for $field from $date: $@\n" if $@;
  };
}

sub _cdr_date_parse {
  my $date = shift;

  return '' unless length($date); #that's okay, it becomes NULL

  #$date =~ /^\s*(\d{4})[\-\/]\(\d{1,2})[\-\/](\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})\s*$/
  $date =~ /^\s*(\d{4})\D(\d{1,2})\D(\d{1,2})\s+(\d{1,2})\D(\d{1,2})\D(\d{1,2})(\D|$)/
    or die "unparsable date: $date"; #maybe we shouldn't die...
  my($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );

  return '' if $year == 1900 && $mon == 1 && $day == 1
            && $hour == 0    && $min == 0 && $sec == 0;

  timelocal($sec, $min, $hour, $day, $mon-1, $year);
}

#taqua  #2007-10-31 08:57:24.113000000

#http://www.the-asterisk-book.com/unstable/funktionen-cdr.html
my %amaflags = (
  DEFAULT       => 0,
  OMIT          => 1, #asterisk 1.4+
  IGNORE        => 1, #asterisk 1.2
  BILLING       => 2, #asterisk 1.4+
  BILL          => 2, #asterisk 1.2
  DOCUMENTATION => 3,
  #? '' => 0,
);

my %import_formats = (
  'asterisk' => [
    'accountcode',
    'src',
    'dst',
    'dcontext',
    'clid',
    'channel',
    'dstchannel',
    'lastapp',
    'lastdata',
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('answerdate'),
    _cdr_date_parser_maker('enddate'),
    'duration',
    'billsec',
    'disposition',
    sub { my($cdr, $amaflags) = @_; $cdr->amaflags($amaflags{$amaflags}); },
    'uniqueid',
    'userfield',
  ],
  'taqua' => [ #some of these are kind arbitrary...

    sub { my($cdr, $field) = @_; },       #XXX interesting RecordType
             # easy to fix: Can't find cdr.cdrtypenum 1 in cdr_type.cdrtypenum

    sub { my($cdr, $field) = @_; },             #all10#RecordVersion
    sub { my($cdr, $field) = @_; },       #OrigShelfNumber
    sub { my($cdr, $field) = @_; },       #OrigCardNumber
    sub { my($cdr, $field) = @_; },       #OrigCircuit
    sub { my($cdr, $field) = @_; },       #OrigCircuitType
    'uniqueid',                           #SequenceNumber
    'accountcode',                        #SessionNumber
    'src',                                #CallingPartyNumber
    'dst',                                #CalledPartyNumber
    _cdr_date_parser_maker('startdate'),  #CallArrivalTime
    _cdr_date_parser_maker('enddate'),    #CallCompletionTime

    #Disposition
    #sub { my($cdr, $d ) = @_; $cdr->disposition( $disposition{$d}): },
    'disposition',
                                          #  -1 => '',
                                          #   0 => '',
                                          # 100 => '',
                                          # 101 => '',
                                          # 102 => '',
                                          # 103 => '',
                                          # 104 => '',
                                          # 105 => '',
                                          # 201 => '',
                                          # 203 => '',

    _cdr_date_parser_maker('answerdate'), #DispositionTime
    sub { my($cdr, $field) = @_; },       #TCAP
    sub { my($cdr, $field) = @_; },       #OutboundCarrierConnectTime
    sub { my($cdr, $field) = @_; },       #OutboundCarrierDisconnectTime

    #TermTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'dstchannel',                         #TermTrunkGroup


    sub { my($cdr, $field) = @_; },       #TermShelfNumber
    sub { my($cdr, $field) = @_; },       #TermCardNumber
    sub { my($cdr, $field) = @_; },       #TermCircuit
    sub { my($cdr, $field) = @_; },       #TermCircuitType
    sub { my($cdr, $field) = @_; },       #OutboundCarrierId
    'charged_party',                      #BillingNumber
    sub { my($cdr, $field) = @_; },       #SubscriberNumber
    'lastapp',                            #ServiceName
    sub { my($cdr, $field) = @_; },       #some weirdness #ChargeTime
    'lastdata',                           #ServiceInformation
    sub { my($cdr, $field) = @_; },       #FacilityInfo
    sub { my($cdr, $field) = @_; },             #all 1900-01-01 0#CallTraceTime
    sub { my($cdr, $field) = @_; },             #all-1#UniqueIndicator
    sub { my($cdr, $field) = @_; },             #all-1#PresentationIndicator
    sub { my($cdr, $field) = @_; },             #empty#Pin
    sub { my($cdr, $field) = @_; },       #CallType
    sub { my($cdr, $field) = @_; },           #Balt/empty #OrigRateCenter
    sub { my($cdr, $field) = @_; },           #Balt/empty #TermRateCenter

    #OrigTrunkGroup
    #it appears channels are actually part of trunk groups, but this data
    #is interesting and we need a source and destination place to put it
    'channel',                            #OrigTrunkGroup

    'userfield',                                #empty#UserDefined
    sub { my($cdr, $field) = @_; },             #empty#PseudoDestinationNumber
    sub { my($cdr, $field) = @_; },             #all-1#PseudoCarrierCode
    sub { my($cdr, $field) = @_; },             #empty#PseudoANI
    sub { my($cdr, $field) = @_; },             #all-1#PseudoFacilityInfo
    sub { my($cdr, $field) = @_; },       #OrigDialedDigits
    sub { my($cdr, $field) = @_; },             #all-1#OrigOutboundCarrier
    sub { my($cdr, $field) = @_; },       #IncomingCarrierID
    'dcontext',                           #JurisdictionInfo
    sub { my($cdr, $field) = @_; },       #OrigDestDigits
    sub { my($cdr, $field) = @_; },       #huh?#InsertTime
    sub { my($cdr, $field) = @_; },       #key
    sub { my($cdr, $field) = @_; },             #empty#AMALineNumber
    sub { my($cdr, $field) = @_; },             #empty#AMAslpID
    sub { my($cdr, $field) = @_; },             #empty#AMADigitsDialedWC
    sub { my($cdr, $field) = @_; },       #OpxOffHook
    sub { my($cdr, $field) = @_; },       #OpxOnHook

        #acctid - primary key
  #AUTO #calldate - Call timestamp (SQL timestamp)
#clid - Caller*ID with text
        #XXX src - Caller*ID number / Source number
        #XXX dst - Destination extension
        #dcontext - Destination context
        #channel - Channel used
        #dstchannel - Destination channel if appropriate
        #lastapp - Last application if appropriate
        #lastdata - Last application data
        #startdate - Start of call (UNIX-style integer timestamp)
        #answerdate - Answer time of call (UNIX-style integer timestamp)
        #enddate - End time of call (UNIX-style integer timestamp)
  #HACK#duration - Total time in system, in seconds
  #HACK#XXX billsec - Total time call is up, in seconds
        #disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
#INT amaflags - What flags to use: BILL, IGNORE etc, specified on a per channel basis like accountcode.
        #accountcode - CDR account number to use: account

        #uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)
        #userfield - CDR user-defined field

        #X cdrtypenum - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
        #XXX charged_party - Service number to be billed
#upstream_currency - Wholesale currency from upstream
#X upstream_price - Wholesale price from upstream
#upstream_rateplanid - Upstream rate plan ID
#rated_price - Rated (or re-rated) price
#distance - km (need units field?)
#islocal - Local - 1, Non Local = 0
#calltypenum - Type of call - see FS::cdr_calltype
#X description - Description (cdr_type 7&8 only) (used for cust_bill_pkg.itemdesc)
#quantity - Number of items (cdr_type 7&8 only)
#carrierid - Upstream Carrier ID (see FS::cdr_carrier)
#upstream_rateid - Upstream Rate ID

        #svcnum - Link to customer service (see FS::cust_svc)
        #freesidestatus - NULL, done (or something)

  ],
  'unitel' => [
    'uniqueid',
    #'cdr_type',
    'cdrtypenum',
    'calldate', # may need massaging?  huh maybe not...
    #'billsec', #XXX duration and billsec?
                sub { $_[0]->billsec(  $_[1] );
                      $_[0]->duration( $_[1] );
                    },
    'src',
    'dst', # XXX needs to have "+61" prepended unless /^\+/ ???
    'charged_party',
    'upstream_currency',
    'upstream_price',
    'upstream_rateplanid',
    'distance',
    'islocal',
    'calltypenum',
    'startdate',  #XXX needs massaging
    'enddate',    #XXX same
    'description',
    'quantity',
    'carrierid',
    'upstream_rateid',
  ],
  'voxlinesystems' => [ #XXX get the actual vendor name
    'disposition',                        #Status
    'startdate',                          #Start (what do you know, a timestamp!
    sub { my($cdr, $field) = @_; },       #Start date
    sub { my($cdr, $field) = @_; },       #Start time
    'enddate',                            #End (also a timestamp!)
    sub { my($cdr, $field) = @_; },       #End date
    sub { my($cdr, $field) = @_; },       #End time
    'accountcode',                        #Calling customer... map to agent_custid??
    sub { my($cdr, $field) = @_; },       #Calling type
    'src',
    'userfield',                          #Calling name #?
    sub { my($cdr, $field) = @_; },       #Called type
    'dst',                                #Called number
    sub { my($cdr, $field) = @_; },       #Destination customer
    sub { my($cdr, $field) = @_; },       #Destination type
    sub { my($cdr, $field) = @_; },       #Destination Number
    sub { my($cdr, $field) = @_; },       #Inbound calling type
    sub { my($cdr, $field) = @_; },       #Inbound calling number
    sub { my($cdr, $field) = @_; },       #Inbound called type
    sub { my($cdr, $field) = @_; },       #Inbound called number
    sub { my($cdr, $field) = @_; },       #Inbound destination type
    sub { my($cdr, $field) = @_; },       #Inbound destination number
    sub { my($cdr, $field) = @_; },       #Outbound calling type
    sub { my($cdr, $field) = @_; },       #Outbound calling number
    sub { my($cdr, $field) = @_; },       #Outbound called type
    sub { my($cdr, $field) = @_; },       #Outbound called number
    sub { my($cdr, $field) = @_; },       #Outbound destination type
    sub { my($cdr, $field) = @_; },       #Outbound destination number
    sub { my($cdr, $field) = @_; },       #Internal calling type
    sub { my($cdr, $field) = @_; },       #Internal calling number
    sub { my($cdr, $field) = @_; },       #Internal called type
    sub { my($cdr, $field) = @_; },       #Internal called number
    sub { my($cdr, $field) = @_; },       #Internal destination type
    sub { my($cdr, $field) = @_; },       #Internal destination number
    'duration',                           #Total seconds
    sub { my($cdr, $field) = @_; },       #Ring seconds
    'billsec',                            #Billable seconds
    'upstream_price',                     #Cost
    sub { my($cdr, $field) = @_; },       #Billing customer
    sub { my($cdr, $field) = @_; },       #Billing customer name
    sub { my($cdr, $field) = @_; },       #Billing type
    sub { my($cdr, $field) = @_; },       #Billing reference
  ],
  'simple' => [

    # Date
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d{1,2})\/(\d{1,2})\/(\d\d(\d\d)?)$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal(0, 0, 0 ,$2, $1-1, $3) );
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $2, $1-1, $3 );
        },

    # Time
    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    # Source_Number
    'src',

    # Terminating_Number
    'dst',

    # Duration
    sub { my($cdr, $min) = @_;
          my $sec = sprintf('%.0f', $min * 60 );
          $cdr->billsec(  $sec );
          $cdr->duration( $sec );
        },

  ],
);

my %import_header = (
  'simple'         => 1,
  'taqua'          => 1,
  'voxlinesystems' => 2, #XXX vendor name
);

=item batch_import HASHREF

Imports CDR records.  Available options are:

=over 4

=item filehandle

=item format

=back

=cut

sub batch_import {
  my $param = shift;

  my $fh = $param->{filehandle};
  my $format = $param->{format};

  return "Unknown format $format" unless exists $import_formats{$format};

  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;

  my $imported = 0;
  #my $columns;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $header_lines =
    exists($import_header{$format}) ? $import_header{$format} : 0;

  my $line;
  while ( defined($line=<$fh>) ) {

    next if $header_lines-- > 0; #&& $line =~ /^[\w, "]+$/ 

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();
    #warn join('-',@columns);

    if ( $format eq 'simple' ) {
      @columns = map { s/^ +//; $_; } @columns;
    }

    my @later = ();
    my %cdr =
      map {

        my $field_or_sub = $_;
        if ( ref($field_or_sub) ) {
          push @later, $field_or_sub, shift(@columns);
          ();
        } else {
          ( $field_or_sub => shift @columns );
        }

      }
      @{ $import_formats{$format} }
    ;

    my $cdr = new FS::cdr ( \%cdr );

    while ( scalar(@later) ) {
      my $sub = shift @later;
      my $data = shift @later;
      &{$sub}($cdr, $data);  # $cdr->&{$sub}($data); 
    }

    if ( $format eq 'taqua' ) {
      if ( $cdr->enddate && $cdr->startdate  ) { #a bit more?
        $cdr->duration( $cdr->enddate - $cdr->startdate  );
      }
      if ( $cdr->enddate && $cdr->answerdate ) { #a bit more?
        $cdr->billsec(  $cdr->enddate - $cdr->answerdate );
      } 
    }

    my $error = $cdr->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;

      #or just skip?
      #next;
    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #might want to disable this if we skip records for any reason...
  return "Empty file!" unless $imported;

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

