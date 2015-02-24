package FS::part_pkg_taxproduct;

use strict;
use vars qw( @ISA $delete_kludge );
use FS::Record qw( qsearch dbh );
use Text::CSV_XS;

@ISA = qw(FS::Record);
$delete_kludge = 0;

=head1 NAME

FS::part_pkg_taxproduct - Object methods for part_pkg_taxproduct records

=head1 SYNOPSIS

  use FS::part_pkg_taxproduct;

  $record = new FS::part_pkg_taxproduct \%hash;
  $record = new FS::part_pkg_taxproduct { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_taxproduct object represents a tax product.
FS::part_pkg_taxproduct inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxproductnum

Primary key

=item data_vendor

Tax data vendor

=item taxproduct

Tax product id from the vendor

=item description

A human readable description of the id in taxproduct

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax product.  To add the tax product to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_taxproduct'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a tax product which has attached package tax rates!"
    if qsearch( 'part_pkg_taxrate', { 'taxproductnum' => $self->taxproductnum } );

  unless ( $delete_kludge ) {
    return "Can't delete a tax product which has attached packages!"
      if qsearch( 'part_pkg', { 'taxproductnum' => $self->taxproductnum } );
  }

  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid tax product.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxproductnum')
    || $self->ut_textn('data_vendor')
    || $self->ut_text('taxproduct')
    || $self->ut_textn('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_pkg_taxrate GEOCODE

Returns the L<FS::part_pkg_taxrate> records (tax definitions) that can apply 
to this tax product category in the location identified by GEOCODE.

=cut

# actually only returns one arbitrary record for each taxclassnum, making 
# it useful only for retrieving the taxclassnums

sub part_pkg_taxrate {
  my $self = shift;
  my $data_vendor = $self->data_vendor; # because duh
  my $geocode = shift;

  my $dbh = dbh;

  # CCH oddness in m2m
  my $extra_sql .= "AND part_pkg_taxrate.data_vendor = '$data_vendor' ".
                   "AND (".
    join(' OR ', map{ 'geocode = '. $dbh->quote(substr($geocode, 0, $_)) }
                 qw(10 5 2)
        ).
    ')';
  # much more CCH oddness in m2m -- this is kludgy
  my $tpnums = join(',',
    map { $_->taxproductnum }
    $self->expand_cch_taxproduct
  );

  # if there are no taxproductnums, there are no matching tax classes
  return if length($tpnums) == 0;

  $extra_sql .= " AND taxproductnum IN($tpnums)";

  my $addl_from = 'LEFT JOIN part_pkg_taxproduct USING ( taxproductnum )';
  my $order_by = 'ORDER BY taxclassnum, length(geocode) desc, length(taxproduct) desc';
  my $select   = 'DISTINCT ON(taxclassnum) *, taxproduct';

  # should qsearch preface columns with the table to facilitate joins?
  qsearch( { 'table'     => 'part_pkg_taxrate',
             'select'    => $select,
             'hashref'   => { 'taxable' => 'Y' },
             'addl_from' => $addl_from,
             'extra_sql' => $extra_sql,
             'order_by'  => $order_by,
         } );
}

=item expand_cch_taxproduct

Returns the full set of part_pkg_taxproduct records that are "implied" by 
this one.

=cut

sub expand_cch_taxproduct {
  my $self = shift;
  my $class = shift;

  my ($a,$b,$c,$d) = split ':', $self->taxproduct;
  $a = '' unless $a; $b = '' unless $b; $c = '' unless $c; $d = '' unless $d;
  my $taxproducts = join(',',
    "'${a}:${b}:${c}:${d}'",
    "'${a}:${b}:${c}:'",
    "'${a}:${b}::${d}'",
    "'${a}:${b}::'"
  );
  qsearch( {
      'table'     => 'part_pkg_taxproduct',
      'hashref'   => { 'data_vendor'=>'cch' },
      'extra_sql' => "AND taxproduct IN($taxproducts)",
  } );
}


=back

=cut

sub batch_import {
  my ($param, $job) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $fh = $param->{filehandle};
  my $format = $param->{format};
  die "unsupported part_pkg_taxproduct format '$format'"
    unless $format eq 'billsoft';

  # this is slightly silly
  my @lines = <$fh>;
  my $lines = scalar @lines;
  seek($fh, 0, 0);
  
  my $imported = 0;
  my $csv = Text::CSV_XS->new;
  # fields: taxproduct, description
  while ( my $row = $csv->getline($fh) ) {
    if (!defined $row) {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    }

    if ( $job ) {
      $job->update_statustext(
        int( 100 * $imported / $lines ) . ',Inserting tax product records'
      );
    }

    my $new = FS::part_pkg_taxproduct->new({
        'data_vendor' => 'billsoft',
        'taxproduct'  => $row->[0],
        'description' => $row->[1],
    });
    my $error = $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error inserting part_pkg_taxproduct: $error\n";
    }
    $imported++;
  }

  $dbh->commit if $oldAutoCommit;
  return '';
}

=head1 BUGS

Confusingly named.  It has nothing to do with part_pkg.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

