package FS::sales;
use base qw( FS::Commission_Mixin FS::Agent_Mixin FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::agent;
use FS::cust_main;
use FS::cust_bill_pkg;
use FS::cust_credit;

=head1 NAME

FS::sales - Object methods for sales records

=head1 SYNOPSIS

  use FS::sales;

  $record = new FS::sales \%hash;
  $record = new FS::sales { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sales object represents a sales person.  FS::sales inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item salesnum

primary key

=item agentnum

agentnum

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new sales person.  To add the sales person to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'sales'; }

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

Checks all fields to make sure this is a valid sales person.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('salesnum')
    || $self->ut_text('salesperson')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_foreign_keyn('sales_custnum', 'cust_main', 'custnum')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item sales_cust_main

Returns the FS::cust_main object (see L<FS::cust_main>), if any, for this
sales person.

=cut

sub sales_cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->sales_custnum } );
}

=item cust_bill_pkg START END OPTIONS

Returns the package line items (see L<FS::cust_bill_pkg>) for which this 
sales person could receive commission.

START and END are an optional date range to limit the results.

OPTIONS may contain:
- I<cust_main_sales>: if this is a true value, sales of packages that have no
package sales person will be included if this is their customer sales person.
- I<classnum>: limit to this package classnum.
- I<paid>: limit to sales that have no unpaid balance.

=cut

sub sales_where {
  my $self = shift;
  my $salesnum = $self->salesnum;
  die "bad salesnum" unless $salesnum =~ /^(\d+)$/;
  my %opt = @_;

  my $cmp_salesnum = 'cust_pkg.salesnum';
  if ($opt{cust_main_sales}) {
    $cmp_salesnum = 'COALESCE(cust_pkg.salesnum, cust_main.salesnum)';
  }

  my @where = ( "$cmp_salesnum    = $salesnum",
                "sales_pkg_class.salesnum = $salesnum"
              );

  # sales_pkg_class number-of-months limit, grr
  # (we should be able to just check for the cust_event record from the 
  # commission credit, but the report is supposed to act as a check on that)
  #
  # Pg-specific, of course
  my $setup_date = 'TO_TIMESTAMP( cust_pkg.setup )';
  my $interval = "(sales_pkg_class.commission_duration || ' months')::interval";
  my $charge_date = 'TO_TIMESTAMP( cust_bill._date )';
  push @where, "CASE WHEN sales_pkg_class.commission_duration IS NOT NULL ".
               "THEN $charge_date < $setup_date + $interval ".
               "ELSE TRUE END";

  @where;
}

sub commission_where {
  my $self = shift;
  'cust_credit.commission_salesnum = ' . $self->salesnum;
}

# slightly modify it
sub cust_bill_pkg_search {
  my $self = shift;
  my $search = $self->SUPER::cust_bill_pkg_search(@_);
  $search->{addl_from} .= '
    JOIN sales_pkg_class ON( COALESCE(sales_pkg_class.classnum, 0) = COALESCE(part_pkg.classnum, 0) )';

  return $search;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

