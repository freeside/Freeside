package FS::cust_credit_bill_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_main_Mixin;
use FS::cust_credit_bill;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;
use FS::cust_tax_exempt_pkg;

@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 NAME

FS::cust_credit_bill_pkg - Object methods for cust_credit_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_credit_bill_pkg;

  $record = new FS::cust_credit_bill_pkg \%hash;
  $record = new FS::cust_credit_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_bill_pkg object represents application of a credit (see 
L<FS::cust_credit_bill>) to a specific line item within an invoice
(see L<FS::cust_bill_pkg>).  FS::cust_credit_bill_pkg inherits from FS::Record.
The following fields are currently supported:

=over 4

=item creditbillpkgnum -  primary key

=item creditbillnum - Credit application to the overall invoice (see L<FS::cust_credit::bill>)

=item billpkgnum - Line item to which credit is applied (see L<FS::cust_bill_pkg>)

=item amount - Amount of the credit applied to this line item.

=item setuprecur - 'setup' or 'recur', designates whether the payment was applied to the setup or recurring portion of the line item.

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_credit_bill_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $payable = $self->cust_bill_pkg->payable($self->setuprecur);
  my $taxable = $self->_is_taxable ? $payable : 0;
  my $part_pkg = $self->cust_bill_pkg->part_pkg;
  my $freq = $part_pkg ? $part_pkg->freq || 1 : 1;# assume unchanged
  my $taxable_per_month = sprintf("%.2f", $taxable / $freq );
  my $credit_per_month = sprintf("%.2f", $self->amount / $freq ); #pennies?

  if ($taxable_per_month >= 0) {  #panic if its subzero?
    my $groupby = 'taxnum,year,month';
    my $sum = 'SUM(amount)';
    my @exemptions = qsearch(
      {
        'select'    => "$groupby, $sum AS amount",
        'table'     => 'cust_tax_exempt_pkg',
        'hashref'   => { billpkgnum => $self->billpkgnum },
        'extra_sql' => "GROUP BY $groupby HAVING $sum > 0",
      }
    ); 
    foreach my $exemption ( @exemptions ) {
      next if $taxable_per_month >= $exemption->amount;
      my $amount = $exemption->amount - $taxable_per_month;
      if ($amount > $credit_per_month) {
             "cust_bill_pkg ". $self->billpkgnum. "  Reducing.\n";
        $amount = $credit_per_month;
      }
      my $cust_tax_exempt_pkg = new FS::cust_tax_exempt_pkg {
        'billpkgnum'       => $self->billpkgnum,
        'creditbillpkgnum' => $self->creditbillpkgnum,
        'amount'           => sprintf('%.2f', 0-$amount),
        map { $_ => $exemption->$_ } split(',', $groupby)
      };
      my $error = $cust_tax_exempt_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_tax_exempt_pkg: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
 '';

}

#helper functions for above
sub _is_taxable {
  my $self = shift;
  my $part_pkg = $self->cust_bill_pkg->part_pkg;

  return 0 unless $part_pkg; #XXX fails for tax on tax

  my $method = $self->setuprecur. 'tax';
  return 0 if $part_pkg->$method =~ /^Y$/i;

  if ($self->billpkgtaxlocationnum) {
    my $location_object = $self->cust_bill_pkg_tax_Xlocation;
    my $tax_object = $location_object->cust_main_county;
    return 0 if $tax_object && $self->tax_object->$method =~ /^Y$/i;
  } #elsif ($self->billpkgtaxratelocationnum) { ... }

  1;
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $original_cust_bill_pkg = $self->cust_bill_pkg;
  my $cust_bill = $original_cust_bill_pkg->cust_bill;

  my %hash = $original_cust_bill_pkg->hash;
  delete $hash{$_} for qw( billpkgnum setup recur );
  $hash{$self->setuprecur} = $self->amount;
  my $cust_bill_pkg = new FS::cust_bill_pkg { %hash };

  use Data::Dumper;
  my @exemptions = qsearch( 'cust_tax_exempt_pkg', 
                            { creditbillpkgnum => $self->creditbillpkgnum }
                          );
  my %seen = ();
  my @generated_exemptions = ();
  my @unseen_exemptions = ();
  foreach my $exemption ( @exemptions ) {
    my $error = $exemption->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error deleting cust_tax_exempt_pkg: $error";
    }

    next if $seen{$exemption->taxnum};
    $seen{$exemption->taxnum} = 1;
    push @unseen_exemptions, $exemption;
  }

  foreach my $exemption ( @unseen_exemptions ) {
    my $tax_object = $exemption->cust_main_county;
    unless ($tax_object) {
      $dbh->rollback if $oldAutoCommit;
      return "can't find exempted tax";
    }
    
    my $hashref_or_error =
      $tax_object->taxline( [ $cust_bill_pkg ], 
                            'custnum'      => $cust_bill->custnum,
                            'invoice_time' => $cust_bill->_date,
                          );
    unless (ref($hashref_or_error)) {
      $dbh->rollback if $oldAutoCommit;
      return "error calculating taxes: $hashref_or_error";
    }

    push @generated_exemptions, @{ $cust_bill_pkg->_cust_tax_exempt_pkg || [] };
  }
                          
  foreach my $taxnum ( keys %seen ) {
    my $sum = 0;
    $sum += $_->amount for grep {$_->taxnum == $taxnum} @exemptions;
    $sum -= $_->amount for grep {$_->taxnum == $taxnum} @generated_exemptions;
    $sum = sprintf("%.2f", $sum);
    unless ($sum eq '0.00' || $sum eq '-0.00') {
      $dbh->rollback if $oldAutoCommit;
      return "Can't unapply credit without charging tax";
    }
  }
   
  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid credit applicaiton.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('creditbillpkgnum')
    || $self->ut_foreign_key('creditbillnum', 'cust_credit_bill', 'creditbillnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_foreign_keyn('billpkgtaxlocationnum',
                              'cust_bill_pkg_tax_location',
                              'billpkgtaxlocationnum')
    || $self->ut_foreign_keyn('billpkgtaxratelocationnum',
                              'cust_bill_pkg_tax_rate_location',
                              'billpkgtaxratelocationnum')
    || $self->ut_money('amount')
    || $self->ut_enum('setuprecur', [ 'setup', 'recur' ] )
    || $self->ut_numbern('sdate')
    || $self->ut_numbern('edate')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub cust_credit_bill {
  my $self = shift;
  qsearchs('cust_credit_bill', { 'creditbillnum' => $self->creditbillnum } );
}

sub cust_bill_pkg {
  my $self = shift;
  qsearchs('cust_bill_pkg', { 'billpkgnum' => $self->billpkgnum } );
}

sub cust_bill_pkg_tax_Xlocation {
  my $self = shift;
  if ($self->billpkg_tax_locationnum) {
    return qsearchs(
      'cust_bill_pkg_tax_location',
      { 'billpkgtaxlocationnum' => $self->billpkgtaxlocationnum },
    );
 
  } elsif ($self->billpkg_tax_rate_locationnum) {
    return qsearchs(
      'cust_bill_pkg_tax_rate_location',
      { 'billpkgtaxratelocationnum' => $self->billpkgtaxratelocationnum },
    );
  } else {
    return undef;
  }
}

=back

=head1 BUGS

B<setuprecur> field is a kludge to compensate for cust_bill_pkg having separate
setup and recur fields.  It should be removed once that's fixed.

B<insert> method assumes that the frequency of the package associated with the
associated line item remains unchanged during the lifetime of the system.
It may get the tax exemption adjustments wrong if package definitions change
frequency.  The presense of delete methods in FS::cust_main_county and
FS::tax_rate makes crediting of old "texas tax" unreliable in the presense of
changing taxes.  Explicit tax credit requests?  Carry 'taxable' onto line
items?

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

