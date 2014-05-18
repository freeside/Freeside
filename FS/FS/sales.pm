package FS::sales;
use base qw( FS::Agent_Mixin FS::Record );

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

sub cust_bill_pkg_search {
  my( $self, $sdate, $edate, %search ) = @_;

  my $cmp_salesnum = delete $search{'cust_main_sales'}
                       ? ' COALESCE( cust_pkg.salesnum, cust_main.salesnum )'
                       : ' cust_pkg.salesnum ';

  my $salesnum = $self->salesnum;
  die "bad salesnum" unless $salesnum =~ /^(\d+)$/;
  my @where = ( "$cmp_salesnum    = $salesnum",
                "sales_pkg_class.salesnum = $salesnum"
              );
  push @where, "cust_bill._date >= $sdate" if $sdate;
  push @where, "cust_bill._date  < $edate" if $edate;

  my $classnum_sql = '';
  if ( exists( $search{'classnum'}  ) ) {
    my $classnum = $search{'classnum'} || '';
    die "bad classnum" unless $classnum =~ /^(\d*)$/;

    push @where,
      "part_pkg.classnum ". ( $classnum ? " = $classnum " : ' IS NULL ' );
  }

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

  if ( $search{'paid'} ) {
    push @where, FS::cust_bill_pkg->owed_sql . ' <= 0.005';
  }

  my $extra_sql = "WHERE ".join(' AND ', map {"( $_ )"} @where);

  { 'table'     => 'cust_bill_pkg',
    'select'    => 'cust_bill_pkg.*',
    'addl_from' => ' LEFT JOIN cust_bill USING ( invnum ) '.
                   ' LEFT JOIN cust_pkg  USING ( pkgnum ) '.
                   ' LEFT JOIN part_pkg  USING ( pkgpart ) '.
                   ' LEFT JOIN cust_main ON ( cust_pkg.custnum = cust_main.custnum )'.
                   ' JOIN sales_pkg_class ON ( '.
                   ' COALESCE( sales_pkg_class.classnum, 0) = COALESCE( part_pkg.classnum, 0) )',
    'extra_sql' => $extra_sql,
 };
}

sub cust_bill_pkg {
  my $self = shift;
  qsearch( $self->cust_bill_pkg_search(@_) )
}

sub cust_credit_search {
  my( $self, $sdate, $edate, %search ) = @_;

  $search{'hashref'}->{'commission_salesnum'} = $self->salesnum;

  my @where = ();
  push @where, "cust_credit._date >= $sdate" if $sdate;
  push @where, "cust_credit._date  < $edate" if $edate;

  my $classnum_sql = '';
  if ( exists($search{'commission_classnum'}) ) {
    my $classnum = delete($search{'commission_classnum'});
    push @where, 'part_pkg.classnum '. ( $classnum ? " = $classnum"
                                                   : " IS NULL "    );

    $search{'addl_from'} .=
      ' LEFT JOIN cust_pkg ON ( commission_pkgnum = cust_pkg.pkgnum ) '.
      ' LEFT JOIN part_pkg USING ( pkgpart ) ';
  }

  my $extra_sql = "AND ".join(' AND ', map {"( $_ )"} @where);

  { 'table'     => 'cust_credit',
    'extra_sql' => $extra_sql,
    %search,
  };
}

sub cust_credit {
  my $self = shift;
  qsearch( $self->cust_credit_search(@_) )
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

