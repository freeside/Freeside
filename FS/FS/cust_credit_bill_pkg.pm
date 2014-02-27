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

  my $cust_bill_pkg = $self->cust_bill_pkg;
  #'payable' is the amount charged (either setup or recur)
  # minus any credit applications, including this one
  my $payable = $cust_bill_pkg->payable($self->setuprecur);
  my $part_pkg = $cust_bill_pkg->part_pkg;
  my $freq = $cust_bill_pkg->freq;
  unless ($freq) {
    $freq = $part_pkg ? ($part_pkg->freq || 1) : 1;#fallback.. assumes unchanged
  }
  my $taxable_per_month = sprintf("%.2f", $payable / $freq );
  my $credit_per_month = sprintf("%.2f", $self->amount / $freq ); #pennies?

  if ($taxable_per_month >= 0) {  #panic if its subzero?
    my $groupby = join(',',
      qw(taxnum year month exempt_monthly exempt_cust 
         exempt_cust_taxname exempt_setup exempt_recur));
    my $sum = 'SUM(amount)';
    my @exemptions = qsearch(
      {
        'select'    => "$groupby, $sum AS amount",
        'table'     => 'cust_tax_exempt_pkg',
        'hashref'   => { billpkgnum => $self->billpkgnum },
        'extra_sql' => "GROUP BY $groupby HAVING $sum > 0",
      }
    ); 
    # each $exemption is now the sum of all monthly exemptions applied to 
    # this line item for a particular taxnum and month.
    foreach my $exemption ( @exemptions ) {
      my $amount = 0;
      if ( $exemption->exempt_monthly ) {
        # finite exemptions
        # $taxable_per_month is AFTER inserting the credit application, so 
        # if it's still larger than the exemption, we don't need to adjust
        next if $taxable_per_month >= $exemption->amount;
        # the amount of 'excess' exemption already in place (above the 
        # remaining charged amount).  We'll de-exempt that much, or the 
        # amount of the new credit, whichever is smaller.
        $amount = $exemption->amount - $taxable_per_month;
        # $amount is the amount of 'excess' exemption already existing 
        # (above the remaining taxable charge amount).  We'll "de-exempt"
        # that much, or the amount of the new credit, whichever is smaller.
        if ($amount > $credit_per_month) {
               "cust_bill_pkg ". $self->billpkgnum. "  Reducing.\n";
          $amount = $credit_per_month;
        }
      } elsif ( $exemption->exempt_setup or $exemption->exempt_recur ) {
        # package defined exemptions: may be setup only, recur only, or both
        my $method = 'exempt_'.$self->setuprecur;
        if ( $exemption->$method ) {
          # then it's exempt from the portion of the charge that this 
          # credit is being applied to
          $amount = $self->amount;
        }
      } else {
        # other types of exemptions: always equal to the amount of
        # the charge
        $amount = $self->amount;
      }
      next if $amount == 0;

      # create a negative exemption
      my $cust_tax_exempt_pkg = new FS::cust_tax_exempt_pkg {
         $exemption->hash, # for exempt_ flags, taxnum, month/year
        'billpkgnum'       => $self->billpkgnum,
        'creditbillpkgnum' => $self->creditbillpkgnum,
        'amount'           => sprintf('%.2f', 0-$amount),
      };

      if ( $cust_tax_exempt_pkg->cust_main_county ) {

        my $error = $cust_tax_exempt_pkg->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "error inserting cust_tax_exempt_pkg: $error";
        }

      }

    } #foreach $exemption
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

  my @negative_exemptions = qsearch('cust_tax_exempt_pkg', {
      'creditbillpkgnum' => $self->creditbillpkgnum
  });

  # de-anti-exempt those negative exemptions
  my $error;
  foreach (@negative_exemptions) {
    $error = $_->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $error = $self->SUPER::delete(@_);
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
  if ($self->billpkgtaxlocationnum) {
    return qsearchs(
      'cust_bill_pkg_tax_location',
      { 'billpkgtaxlocationnum' => $self->billpkgtaxlocationnum },
    );
 
  } elsif ($self->billpkgtaxratelocationnum) {
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

B<insert> method used to assume that the frequency of the package associated
with the associated line item remained unchanged during the lifetime of the
system.  That is still used as a fallback.  It may get the tax exemption
adjustments wrong if package definitions change frequency.  The presense of
delete methods in FS::cust_main_county and FS::tax_rate makes crediting of
old "texas tax" unreliable in the presense of changing taxes.  Explicit tax
credit requests?  Carry 'taxable' onto line items?

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

