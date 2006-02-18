package FS::cdr;

use strict;
use vars qw( @ISA );
use Date::Parse;
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::cdr_type;
use FS::cdr_calltype;
use FS::cdr_carrier;

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

=back

=item accountcode - CDR account number to use: account

=item uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)

=item userfield - CDR user-defined field

=item cdr_type - CDR type - see L<FS::cdr_type> (Usage = 1, S&E = 7, OC&C = 8)

=item charged_party - Service number to be billed

=item upstream_currency - Wholesale currency from upstream

=item upstream_price - Wholesale price from upstream

=item upstream_rateplanid - Upstream rate plan ID

=item distance - km (need units field?)

=item islocal - Local - 1, Non Local = 0

=item calltypenum - Type of call - see L<FS::cdr_calltype>

=item description - Description (cdr_type 7&8 only) (used for cust_bill_pkg.itemdesc)

=item quantity - Number of items (cdr_type 7&8 only)

=item carrierid - Upstream Carrier ID (see L<FS::cdr_carrier>) 

=cut

#Telstra =1, Optus = 2, RSL COM = 3

=back

=item upstream_rateid - Upstream Rate ID

=item svcnum - Link to customer service (see L<FS::cust_svc>)

=item freesidestatus - NULL, done, skipped, pushed_downstream (or something)

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

my %formats = (
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
    'startdate', # XXX will need massaging
    'answer',    # XXX same
    'end',       # XXX same
    'duration',
    'billsec',
    'disposition',
    'amaflags',
    'uniqueid',
    'userfield',
  ],
  'unitel' => [
    'uniqueid',
    'cdr_type',
    'calldate', # XXX may need massaging
    'billsec', #XXX duration and billsec?
               # sub { $_[0]->billsec(  $_[1] );
               #       $_[0]->duration( $_[1] );
               #     },
    'src',
    'dst',
    'charged_party',
    'upstream_currency',
    'upstream_price',
    'upstream_rateplanid',
    'distance',
    'islocal',
    'calltypenum',
    'startdate', # XXX will definitely need massaging
    'enddate',   # XXX same
    'description',
    'quantity',
    'carrierid',
    'upstream_rateid',
  ]
);

sub batch_import {
  my $param = shift;

  my $fh = $param->{filehandle};
  my $format = $param->{format};

  return "Unknown format $format" unless exists $formats{$format};

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
  
  my $line;
  while ( defined($line=<$fh>) ) {

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();
    #warn join('-',@columns);

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
      @{ $formats{$format} }
    ;

    my $cdr = new FS::cdr ( \%cdr );

    while ( scalar(@later) ) {
      my $sub = shift @later;
      my $data = shift @later;
      &{$sub}($cdr, $data);  # $cdr->&{$sub}($data); 
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

