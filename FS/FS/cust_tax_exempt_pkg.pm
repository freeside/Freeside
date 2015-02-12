package FS::cust_tax_exempt_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main_Mixin;
use FS::cust_bill_pkg;
use FS::cust_main_county;
use FS::tax_rate;
use FS::cust_credit_bill_pkg;
use FS::UID qw(dbh);
use FS::upgrade_journal;

# some kind of common ancestor with cust_bill_pkg_tax_location would make sense

@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 NAME

FS::cust_tax_exempt_pkg - Object methods for cust_tax_exempt_pkg records

=head1 SYNOPSIS

  use FS::cust_tax_exempt_pkg;

  $record = new FS::cust_tax_exempt_pkg \%hash;
  $record = new FS::cust_tax_exempt_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_tax_exempt_pkg object represents a record of a customer tax
exemption.  Whenever a package would be taxed (based on its location and
taxclass), but some or all of it is exempt from taxation, an 
FS::cust_tax_exempt_pkg record is created.

FS::cust_tax_exempt inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item exemptpkgnum - primary key

=item billpkgnum - invoice line item (see L<FS::cust_bill_pkg>) that 
was exempted from tax.

=item taxtype - the object class of the tax record ('FS::cust_main_county'
or 'FS::tax_rate').

=item taxnum - tax rate (see L<FS::cust_main_county>)

=item year - the year in which the exemption occurred.  NULL if this 
is a customer or package exemption rather than a monthly exemption.

=item month - the month in which the exemption occurred.  NULL if this
is a customer or package exemption.

=item amount - the amount of revenue exempted.  For monthly exemptions
this may be anything up to the monthly exemption limit defined in 
L<FS::cust_main_county> for this tax.  For customer exemptions it is 
always the full price of the line item.  For package exemptions it 
may be the setup fee, the recurring fee, or the sum of those.

=item exempt_cust - flag indicating that the customer is tax-exempt
(cust_main.tax = 'Y').

=item exempt_cust_taxname - flag indicating that the customer is exempt 
from the tax with this name (see L<FS::cust_main_exemption).

=item exempt_setup, exempt_recur: flag indicating that the package's setup
or recurring fee is not taxable (part_pkg.setuptax and part_pkg.recurtax).

=item exempt_monthly: flag indicating that this is a monthly per-customer
exemption (Texas tax).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new exemption record.  To add the examption record to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_tax_exempt_pkg'; }

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

Checks all fields to make sure this is a valid exemption record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('exemptnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_enum('taxtype', [ 'FS::cust_main_county', 'FS::tax_rate' ])
    || $self->ut_foreign_keyn('creditbillpkgnum',
                              'cust_credit_bill_pkg',
                              'creditbillpkgnum')
    || $self->ut_numbern('year') #check better
    || $self->ut_numbern('month') #check better
    || $self->ut_money('amount')
    || $self->ut_flag('exempt_cust')
    || $self->ut_flag('exempt_setup')
    || $self->ut_flag('exempt_recur')
    || $self->ut_flag('exempt_cust_taxname')
    || $self->SUPER::check
  ;

  $self->get('taxtype') =~ /^FS::(\w+)$/;
  my $rate_table = $1;
  $error ||= $self->ut_foreign_key('taxnum', $rate_table, 'taxnum');

  return $error if $error;

  if ( $self->get('exempt_cust') ) {
    $self->set($_ => '') for qw(
      exempt_cust_taxname exempt_setup exempt_recur exempt_monthly month year
    );
  } elsif ( $self->get('exempt_cust_taxname')  ) {
    $self->set($_ => '') for qw(
      exempt_setup exempt_recur exempt_monthly month year
    );
  } elsif ( $self->get('exempt_setup') || $self->get('exempt_recur') ) {
    $self->set($_ => '') for qw(exempt_monthly month year);
  } elsif ( $self->get('exempt_monthly') ) {
    $self->year =~ /^\d{4}$/
        or return "illegal exemption year: '".$self->year."'";
    $self->month >= 1 && $self->month <= 12
        or return "illegal exemption month: '".$self->month."'";
  } else {
    return "no exemption type selected";
  }

  '';
}

=item cust_main_county

=item tax_rate

Returns the associated tax definition if it still exists in the database.
Otherwise returns false.

=cut

sub cust_main_county {
  my $self = shift;
  my $class = $self->taxtype;
  $class->by_key($self->taxnum);
}

sub tax_rate {
  my $self = shift;
  my $class = $self->taxtype;
  $class->by_key($self->taxnum);
}

sub _upgrade_data {
  my $class = shift;

  my $journal = 'cust_tax_exempt_pkg_flags';
  if ( !FS::upgrade_journal->is_done($journal) ) {
    my $sql = "UPDATE cust_tax_exempt_pkg SET exempt_monthly = 'Y' ".
              "WHERE month IS NOT NULL";
    dbh->do($sql) or die dbh->errstr;
    FS::upgrade_journal->set_done($journal);
  }

  $journal = 'cust_tax_exempt_pkg_taxtype';
  if ( !FS::upgrade_journal->is_done($journal) ) {
    my $sql = "UPDATE cust_tax_exempt_pkg ".
              "SET taxtype = 'FS::cust_main_county' WHERE taxtype IS NULL";
    dbh->do($sql) or die dbh->errstr;
    $sql =    "UPDATE cust_tax_exempt_pkg_void ".
              "SET taxtype = 'FS::cust_main_county' WHERE taxtype IS NULL";
    dbh->do($sql) or die dbh->errstr;
    FS::upgrade_journal->set_done($journal);
  }


}

=back

=head1 BUGS

Texas tax is still a royal pain in the ass.

=head1 SEE ALSO

L<FS::cust_main_county>, L<FS::cust_bill_pkg>, L<FS::Record>, schema.html from
the base documentation.

=cut

1;

