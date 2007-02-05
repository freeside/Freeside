package FS::cust_pay_batch;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw(dbh qsearch qsearchs);
use FS::payinfo_Mixin;
use Business::CreditCard 0.28;

@ISA = qw( FS::Record FS::payinfo_Mixin );

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;

=head1 NAME

FS::cust_pay_batch - Object methods for batch cards

=head1 SYNOPSIS

  use FS::cust_pay_batch;

  $record = new FS::cust_pay_batch \%hash;
  $record = new FS::cust_pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->retriable;

=head1 DESCRIPTION

An FS::cust_pay_batch object represents a credit card transaction ready to be
batched (sent to a processor).  FS::cust_pay_batch inherits from FS::Record.  
Typically called by the collect method of an FS::cust_main object.  The
following fields are currently supported:

=over 4

=item paybatchnum - primary key (automatically assigned)

=item batchnum - indentifies group in batch

=item payby - CARD/CHEK/LECB/BILL/COMP

=item payinfo

=item exp - card expiration 

=item amount 

=item invnum - invoice

=item custnum - customer 

=item payname - name on card 

=item first - name 

=item last - name 

=item address1 

=item address2 

=item city 

=item state 

=item zip 

=item country 

=item status

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pay_batch'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.  If there is an error, returns the error,
otherwise returns false.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid transaction.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
      $self->ut_numbern('paybatchnum')
    || $self->ut_numbern('trancode') #deprecated
    || $self->ut_money('amount')
    || $self->ut_number('invnum')
    || $self->ut_number('custnum')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('state')
  ;

  return $error if $error;

  $self->getfield('last') =~ /^([\w \,\.\-\']+)$/ or return "Illegal last name";
  $self->setfield('last',$1);

  $self->first =~ /^([\w \,\.\-\']+)$/ or return "Illegal first name";
  $self->first($1);

  $error = $self->payinfo_check();
  return $error if $error;

  if ( $self->exp eq '' ) {
    return "Expiration date required"
      unless $self->payby =~ /^(CHEK|DCHK|LECB|WEST)$/;
    $self->exp('');
  } else {
    if ( $self->exp =~ /^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/ ) {
      $self->exp("$1-$2-$3");
    } elsif ( $self->exp =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      if ( length($2) == 4 ) {
        $self->exp("$2-$1-01");
      } elsif ( $2 > 98 ) { #should pry change to check for "this year"
        $self->exp("19$2-$1-01");
      } else {
        $self->exp("20$2-$1-01");
      }
    } else {
      return "Illegal expiration date";
    }
  }

  if ( $self->payname eq '' ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\']+)$/
      or return "Illegal billing name";
    $self->payname($1);
  }

  #we have lots of old zips in there... don't hork up batch results cause of em
  $self->zip =~ /^\s*(\w[\w\-\s]{2,8}\w)\s*$/
    or return "Illegal zip: ". $self->zip;
  $self->zip($1);

  $self->country =~ /^(\w\w)$/ or return "Illegal country: ". $self->country;
  $self->country($1);

  #$error = $self->ut_zip('zip', $self->country);
  #return $error if $error;

  #check invnum, custnum, ?

  $self->SUPER::check;
}

=item cust_main

Returns the customer (see L<FS::cust_main>) for this batched credit card
payment.

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item retriable

Marks the corresponding event (see L<FS::cust_bill_event>) for this batched
credit card payment as retriable.  Useful if the corresponding financial
institution account was declined for temporary reasons and/or a manual 
retry is desired.

Implementation details: For the named customer's invoice, changes the
statustext of the 'done' (without statustext) event to 'retriable.'

=cut

sub retriable {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';        #Hmm
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $self->invnum } )
    or return "event $self->eventnum references nonexistant invoice $self->invnum";

  warn "cust_pay_batch->retriable working with self of " . $self->paybatchnum . " and invnum of " . $self->invnum;
  my @cust_bill_event =
    sort { $a->part_bill_event->seconds <=> $b->part_bill_event->seconds }
      grep {
        $_->part_bill_event->eventcode =~ /\$cust_bill->batch_card/
	  && $_->status eq 'done'
	  && ! $_->statustext
	}
      $cust_bill->cust_bill_event;
  # complain loudly if scalar(@cust_bill_event) > 1 ?
  my $error = $cust_bill_event[0]->retriable;
  if ($error ) {
    # gah, even with transactions.
    $dbh->commit if $oldAutoCommit; #well.
    return "error marking invoice event retriable: $error";
  }
  '';
}

=back

=head1 BUGS

There should probably be a configuration file with a list of allowed credit
card types.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

