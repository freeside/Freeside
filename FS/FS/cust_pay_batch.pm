package FS::cust_pay_batch;

use strict;
use vars qw( @ISA );
use FS::Record qw(dbh qsearchs);
use Business::CreditCard;

@ISA = qw( FS::Record );

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

=head1 DESCRIPTION

An FS::cust_pay_batch object represents a credit card transaction ready to be
batched (sent to a processor).  FS::cust_pay_batch inherits from FS::Record.  
Typically called by the collect method of an FS::cust_main object.  The
following fields are currently supported:

=over 4

=item paybatchnum - primary key (automatically assigned)

=item cardnum

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

#inactive
#
#Replaces the OLD_RECORD with this one in the database.  If there is an error,
#returns the error, otherwise returns false.

=cut

sub replace {
  return "Can't (yet?) replace batched transactions!";
}

=item check

Checks all fields to make sure this is a valid transaction.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $error = 
      $self->ut_numbern('paybatchnum')
    || $self->ut_numbern('trancode') #depriciated
    || $self->ut_number('cardnum') 
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

  my $cardnum = $self->cardnum;
  $cardnum =~ s/\D//g;
  $cardnum =~ /^(\d{13,16})$/
    or return "Illegal credit card number";
  $cardnum = $1;
  $self->cardnum($cardnum);
  validate($cardnum) or return "Illegal credit card number";
  return "Unknown card type" if cardtype($cardnum) eq "Unknown";

  if ( $self->exp eq '' ) {
    return "Expriation date required"; #unless 
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

  #$self->zip =~ /^\s*(\w[\w\-\s]{3,8}\w)\s*$/
  #  or return "Illegal zip: ". $self->zip;
  #$self->zip($1);

  $self->country =~ /^(\w\w)$/ or return "Illegal country: ". $self->country;
  $self->country($1);

  $error = $self->ut_zip('zip', $self->country);
  return $error if $error;

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

=back

=head1 SUBROUTINES

=over 4

=item import_results

=cut

sub import_results {
  use Time::Local;
  use FS::cust_pay;
  eval "use Text::CSV_XS;";
  die $@ if $@;
#
  my $param = shift;
  my $fh = $param->{'filehandle'};
  my $format = $param->{'format'};
  my $paybatch = $param->{'paybatch'};

  my @fields;
  my $end_condition;
  my $end_hook;
  my $hook;
  my $approved_condition;
  my $declined_condition;

  if ( $format eq 'csv-td_canada_trust-merchant_pc_batch' ) {

    @fields = (
      'paybatchnum', # Reference#:  Invoice number of the transaction
      'paid',        # Amount:  Amount of the transaction.  Dollars and cents
                     #          with no decimal entered.
      '',            # Card Type:  0 - MCrd, 1 - Visa, 2 - AMEX, 3 - Discover,
                     #             4 - Insignia, 5 - Diners/EnRoute, 6 - JCB
      '_date',       # Transaction Date:  Date the Transaction was processed
      'time',        # Transaction Time:  Time the transaction was processed
      'payinfo',     # Card Number:  Card number for the transaction
      '',            # Expiry Date:  Expiry date of the card
      '',            # Auth#:  Authorization number entered for force post
                     #         transaction
      'type',        # Transaction Type:  0 - purchase, 40 - refund,
                     #                    20 - force post
      'result',      # Processing Result: 3 - Approval,
                     #                    4 - Declined/Amount over limit,
                     #                    5 - Invalid/Expired/stolen card,
                     #                    6 - Comm Error
      '',            # Terminal ID: Terminal ID used to process the transaction
    );

    $end_condition = sub {
      my $hash = shift;
      $hash->{'type'} eq '0BC';
    };

    $end_hook = sub {
      my( $hash, $total) = @_;
      $total = sprintf("%.2f", $total);
      my $batch_total = sprintf("%.2f", $hash->{'paybatchnum'} / 100 );
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      '';
    };

    $hook = sub {
      my $hash = shift;
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} / 100 );
      $hash->{'_date'} = timelocal( substr($hash->{'time'},  4, 2),
                                    substr($hash->{'time'},  2, 2),
                                    substr($hash->{'time'},  0, 2),
                                    substr($hash->{'_date'}, 6, 2),
                                    substr($hash->{'_date'}, 4, 2)-1,
                                    substr($hash->{'_date'}, 0, 4)-1900, );
    };

    $approved_condition = sub {
      my $hash = shift;
      $hash->{'type'} eq '0' && $hash->{'result'} == 3;
    };

    $declined_condition = sub {
      my $hash = shift;
      $hash->{'type'} eq '0' && (    $hash->{'result'} == 4
                                  || $hash->{'result'} == 5 );
    };


  } else {
    return "Unknown format $format";
  }

  my $csv = new Text::CSV_XS;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $total = 0;
  my $line;
  while ( defined($line=<$fh>) ) {

    next if $line =~ /^\s*$/; #skip blank lines

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @values = $csv->fields();
    my %hash;
    foreach my $field ( @fields ) {
      my $value = shift @values;
      next unless $field;
      $hash{$field} = $value;
    }

    if ( &{$end_condition}(\%hash) ) {
      my $error = &{$end_hook}(\%hash, $total);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      last;
    }

    my $cust_pay_batch =
      qsearchs('cust_pay_batch', { 'paybatchnum' => $hash{'paybatchnum'} } );
    unless ( $cust_pay_batch ) {
      $dbh->rollback if $oldAutoCommit;
      return "unknown paybatchnum $hash{'paybatchnum'}\n";
    }
    my $custnum = $cust_pay_batch->custnum,

    my $error = $cust_pay_batch->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error removing paybatchnum $hash{'paybatchnum'}: $error\n";
    }

    &{$hook}(\%hash);

    if ( &{$approved_condition}(\%hash) ) {

      my $cust_pay = new FS::cust_pay ( {
        'custnum'  => $custnum,
        'payby'    => 'CARD',
        'paybatch' => $paybatch,
        map { $_ => $hash{$_} } (qw( paid _date payinfo )),
      } );
      $error = $cust_pay->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error adding payment paybatchnum $hash{'paybatchnum'}: $error\n";
      }
      $total += $hash{'paid'};
  
      $cust_pay->cust_main->apply_payments;

    } elsif ( &{$declined_condition}(\%hash) ) {

      #this should be configurable... if anybody else ever uses batches
      $cust_pay_batch->cust_main->suspend;

    }

  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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

