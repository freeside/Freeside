package FS::pay_batch;

use strict;
use vars qw( @ISA );
use Time::Local;
use Text::CSV_XS;
use FS::Record qw( dbh qsearch qsearchs );
use FS::cust_pay;
use FS::part_bill_event qw(due_events);

@ISA = qw(FS::Record);

=head1 NAME

FS::pay_batch - Object methods for pay_batch records

=head1 SYNOPSIS

  use FS::pay_batch;

  $record = new FS::pay_batch \%hash;
  $record = new FS::pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pay_batch object represents an example.  FS::pay_batch inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item batchnum - primary key

=item payby - CARD or CHEK

=item status - O (Open), I (In-transit), or R (Resolved)

=item download - 

=item upload - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'pay_batch'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('batchnum')
    || $self->ut_enum('payby', [ 'CARD', 'CHEK' ])
    || $self->ut_enum('status', [ 'O', 'I', 'R' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rebalance

=cut

sub rebalance {
  my $self = shift;
}

=item set_status 

=cut

sub set_status {
  my $self = shift;
  $self->status(shift);
  $self->download(time)
    if $self->status eq 'I' && ! $self->download;
  $self->upload(time)
    if $self->status eq 'R' && ! $self->upload;
  $self->replace();
}

=item import results OPTION => VALUE, ...

Import batch results.

Options are:

I<filehandle> - open filehandle of results file.

I<format> - "csv-td_canada_trust-merchant_pc_batch", "csv-chase_canada-E-xactBatch", "ach-spiritone", or "PAP"

=cut

sub import_results {
  my $self = shift;

  my $param = ref($_[0]) ? shift : { @_ };
  my $fh = $param->{'filehandle'};
  my $format = $param->{'format'};

  my $filetype;      # CSV, Fixed80, Fixed264
  my @fields;
  my $formatre;      # for Fixed.+
  my @values;
  my $begin_condition;
  my $end_condition;
  my $end_hook;
  my $hook;
  my $approved_condition;
  my $declined_condition;

  if ( $format eq 'csv-td_canada_trust-merchant_pc_batch' ) {

    $filetype = "CSV";

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


  }elsif ( $format eq 'csv-chase_canada-E-xactBatch' ) {

    $filetype = "CSV";

    @fields = (
      '',            # Internal(bank) id of the transaction
      '',            # Transaction Type:  00 - purchase,      01 - preauth,
                     #                    02 - completion,    03 - forcepost,
                     #                    04 - refund,        05 - auth,
                     #                    06 - purchase corr, 07 - refund corr,
                     #                    08 - void           09 - void return
      '',            # gateway used to process this transaction
      'paid',        # Amount:  Amount of the transaction.  Dollars and cents
                     #          with decimal entered.
      'auth',        # Auth#:  Authorization number (if approved)
      'payinfo',     # Card Number:  Card number for the transaction
      '',            # Expiry Date:  Expiry date of the card
      '',            # Cardholder Name
      'bankcode',    # Bank response code (3 alphanumeric)
      'bankmess',    # Bank response message
      'etgcode',     # ETG response code (2 alphanumeric)
      'etgmess',     # ETG response message
      '',            # Returned customer number for the transaction
      'paybatchnum', # Reference#:  paybatch number of the transaction
      '',            # Reference#:  Invoice number of the transaction
      'result',      # Processing Result: Approved of Declined
    );

    $end_condition = sub {
      '';
    };

    $hook = sub {
      my $hash = shift;
      my $cpb = shift;
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'}); #hmmmm
      $hash->{'_date'} = time;  # got a better one?
      $hash->{'payinfo'} = $cpb->{'payinfo'}
        if( substr($hash->{'payinfo'}, -4) eq substr($cpb->{'payinfo'}, -4) );
    };

    $approved_condition = sub {
      my $hash = shift;
      $hash->{'etgcode'} eq '00' && $hash->{'result'} eq "Approved";
    };

    $declined_condition = sub {
      my $hash = shift;
      $hash->{'etgcode'} ne '00' # internal processing error
        || ( $hash->{'result'} eq "Declined" );
    };


  }elsif ( $format eq 'PAP' ) {

    $filetype = "Fixed264";

    @fields = (
      'recordtype',  # We are interested in the 'D' or debit records
      'batchnum',    # Record#:  batch number we used when sending the file
      'datacenter',  # Where in the bowels of the bank the data was processed
      'paid',        # Amount:  Amount of the transaction.  Dollars and cents
                     #          with no decimal entered.
      '_date',       # Transaction Date:  Date the Transaction was processed
      'bank',        # Routing information
      'payinfo',     # Account number for the transaction
      'paybatchnum', # Reference#:  Invoice number of the transaction
    );

    $formatre = '^(.).{19}(.{4})(.{3})(.{10})(.{6})(.{9})(.{12}).{110}(.{19}).{71}$'; 

    $end_condition = sub {
      my $hash = shift;
      $hash->{'recordtype'} eq 'W';
    };

    $end_hook = sub {
      my( $hash, $total) = @_;
      $total = sprintf("%.2f", $total);
      my $batch_total = $hash->{'datacenter'}.$hash->{'paid'}.
                        substr($hash->{'_date'},0,1);          # YUCK!
      $batch_total = sprintf("%.2f", $batch_total / 100 );
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      '';
    };

    $hook = sub {
      my $hash = shift;
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} / 100 );
      my $tmpdate = timelocal( 0,0,1,1,0,substr($hash->{'_date'}, 0, 3)+2000); 
      $tmpdate += 86400*(substr($hash->{'_date'}, 3, 3)-1) ;
      $hash->{'_date'} = $tmpdate;
      $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'bank'};
    };

    $approved_condition = sub {
      1;
    };

    $declined_condition = sub {
      0;
    };

  }elsif ( $format eq 'ach-spiritone' ) {

    $filetype = "CSV";

    @fields = (
      '',            # Name
      'paybatchnum', # ID:  Invoice number of the transaction
      'aba',         # ABA Number for the transaction
      'payinfo',     # Bank Account Number for the transaction
      '',            # Transaction Type:  27 - debit
      'paid',        # Amount:  Amount of the transaction.  Dollars and cents
                     #          with decimal entered.
      '',            # Default Transaction Type
      '',            # Default Amount:  Dollars and cents with decimal entered.
    );

    $end_condition = sub {
      '';
    };

    $hook = sub {
      my $hash = shift;
      $hash->{'_date'} = time;  # got a better one?
      $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'aba'};
    };

    $approved_condition = sub {
      1;
    };

    $declined_condition = sub {
      0;
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

  my $reself = $self->select_for_update;

  unless ( $reself->status eq 'I' ) {
    $dbh->rollback if $oldAutoCommit;
    return "batchnum ". $self->batchnum. "no longer in transit";
  };

  my $error = $self->set_status('R');
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error
  }

  my $total = 0;
  my $line;
  while ( defined($line=<$fh>) ) {

    next if $line =~ /^\s*$/; #skip blank lines

    if ($filetype eq "CSV") {
      $csv->parse($line) or do {
        $dbh->rollback if $oldAutoCommit;
        return "can't parse: ". $csv->error_input();
      };
      @values = $csv->fields();
    }elsif ($filetype eq "Fixed80" || $filetype eq "Fixed264"){
      @values = $line =~ /$formatre/;
      unless (@values) {
        $dbh->rollback if $oldAutoCommit;
        return "can't parse: ". $line;
      };
    }else{
      $dbh->rollback if $oldAutoCommit;
      return "Unknown file type $filetype";
    }

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
      qsearchs('cust_pay_batch', { 'paybatchnum' => $hash{'paybatchnum'}+0 } );
    unless ( $cust_pay_batch ) {
      return "unknown paybatchnum $hash{'paybatchnum'}\n";
    }
    my $custnum = $cust_pay_batch->custnum,
    my $payby = $cust_pay_batch->payby,

    my $new_cust_pay_batch = new FS::cust_pay_batch { $cust_pay_batch->hash };

    &{$hook}(\%hash, $cust_pay_batch->hashref);

    if ( &{$approved_condition}(\%hash) ) {

      $new_cust_pay_batch->status('Approved');

      my $cust_pay = new FS::cust_pay ( {
        'custnum'  => $custnum,
	'payby'    => $payby,
        'paybatch' => $self->batchnum,
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

      $new_cust_pay_batch->status('Declined');

      foreach my $part_bill_event ( due_events ( $new_cust_pay_batch,
                                                 'DCLN',
						 '',
						 '') ) {

        # don't run subsequent events if balance<=0
        last if $cust_pay_batch->cust_main->balance <= 0;

	if (my $error = $part_bill_event->do_event($new_cust_pay_batch)) {
	  # gah, even with transactions.
	  $dbh->commit if $oldAutoCommit; #well.
	  return $error;
	}

      }

    }

    my $error = $new_cust_pay_batch->replace($cust_pay_batch);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error updating status of paybatchnum $hash{'paybatchnum'}: $error\n";
    }

  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=back

=head1 BUGS

status is somewhat redundant now that download and upload exist

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

