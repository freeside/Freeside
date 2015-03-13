package FS::Commission_Mixin;

use strict;
use FS::Record 'qsearch';

=head1 NAME

FS::Commission_Mixin - Common interface for entities that can receive 
sales commissions.

=head1 INTERFACE

=over 4

=item commission_where

Returns an SQL WHERE fragment to search for commission credits belonging
to this entity.

=item sales_where

Returns an SQL WHERE fragment to search for sales records
(L<FS::cust_bill_pkg>) that would be assigned to this entity for commission.

=cut

sub commission_where { ... }

=head1 METHODS

=over 4

=item cust_credit_search START, END, OPTIONS 

Returns a qsearch hashref for the commission credits given to this entity.
START and END are a date range.

OPTIONS may optionally contain "commission_classnum", a package classnum to
limit the commission packages.

=cut

sub cust_credit_search {
  my( $self, $sdate, $edate, %search ) = @_;

  my @where = ( $self->commission_where );
  push @where, "cust_credit._date >= $sdate" if $sdate;
  push @where, "cust_credit._date  < $edate" if $edate;
  
  my $classnum_sql = '';
  my $addl_from = '';
  if ( exists($search{'commission_classnum'}) ) {
    my $classnum = delete($search{'commission_classnum'});
    push @where, 'part_pkg.classnum '. ( $classnum ? " = $classnum"
                                                   : " IS NULL "    );

    $addl_from =
      ' LEFT JOIN cust_pkg ON ( commission_pkgnum = cust_pkg.pkgnum ) '.
      ' LEFT JOIN part_pkg USING ( pkgpart ) ';
  }

  my $extra_sql = 'WHERE ' . join(' AND ', map {"( $_ )"} @where);

  { 'table'     => 'cust_credit',
    'addl_from' => $addl_from,
    'extra_sql' => $extra_sql,
  };
}

=item cust_credit START, END, OPTIONS

Takes the same options as cust_credit_search, and performs the search.

=cut

sub cust_credit {
  my $self = shift;
  qsearch( $self->cust_credit_search(@_) );
}

=item cust_bill_pkg_search START, END, OPTIONS

Returns a qsearch hashref for the sales for which this entity could receive
commission. START and END are a date range; OPTIONS may contain:
- I<classnum>: limit to this package class (or null, if it's empty)
- I<paid>: limit to sales that have no unpaid balance (as of now)

=cut

sub cust_bill_pkg_search {
  my( $self, $sdate, $edate, %search ) = @_;
  
  my @where = $self->sales_where(%search);
  push @where, "cust_bill._date >= $sdate" if $sdate;
  push @where, "cust_bill._date  < $edate" if $edate;
  
  my $classnum_sql = '';
  if ( exists( $search{'classnum'}  ) ) { 
    my $classnum = $search{'classnum'} || '';
    die "bad classnum" unless $classnum =~ /^(\d*)$/;
    
    push @where,
      "part_pkg.classnum ". ( $classnum ? " = $classnum " : ' IS NULL ' );
  }
  
  if ( $search{'paid'} ) {
    push @where, FS::cust_bill_pkg->owed_sql . ' <= 0.005';
  }
  
  my $extra_sql = "WHERE ".join(' AND ', map {"( $_ )"} @where);

  { 'table'     => 'cust_bill_pkg',
    'select'    => 'cust_bill_pkg.*',
    'addl_from' => ' LEFT JOIN cust_bill USING ( invnum ) '.
                   ' LEFT JOIN cust_pkg  USING ( pkgnum ) '.
                   ' LEFT JOIN part_pkg  USING ( pkgpart ) '.
                   ' LEFT JOIN cust_main ON ( cust_pkg.custnum = cust_main.custnum )',
    'extra_sql' => $extra_sql,
 };
}

=item cust_bill_pkg START, END, OPTIONS

Same as L</cust_bill_pkg_search> but then performs the search.

=back

=head1 SEE ALSO

L<FS::cust_credit>

=cut

1;
