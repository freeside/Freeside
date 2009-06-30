package FS::part_pkg_taxclass;

use strict;
use vars qw( @ISA );
use FS::UID qw( dbh );
use FS::Record; # qw( qsearch qsearchs );
use FS::cust_main_county;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_taxclass - Object methods for part_pkg_taxclass records

=head1 SYNOPSIS

  use FS::part_pkg_taxclass;

  $record = new FS::part_pkg_taxclass \%hash;
  $record = new FS::part_pkg_taxclass { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_taxclass object represents a tax class.  FS::part_pkg_taxclass
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item taxclassnum

Primary key

=item taxclass

Tax class

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax class.  To add the tax class to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_taxclass'; }

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

  my $sth = dbh->prepare("
    SELECT country, state, county FROM cust_main_county
      WHERE taxclass IS NOT NULL AND taxclass != ''
      GROUP BY country, state, county
  ") or die dbh->errstr;
  $sth->execute or die $sth->errstr;

  while ( my $row = $sth->fetchrow_hashref ) {
    #warn "inserting for $row";
    my $cust_main_county = new FS::cust_main_county {
      'country'  => $row->{country},
      'state'    => $row->{state},
      'county'   => $row->{county},
      'tax'      => 0,
      'taxclass' => $self->taxclass,
      #exempt_amount
      #taxname
      #setuptax
      #recurtax
    };
    $error = $cust_main_county->insert;
    #last if $error;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  return "Can't change tax class name (disable and create anew)"
    if $old->taxclass ne $new->taxclass;

  $new->SUPER::replace(@_);
}

=item check

Checks all fields to make sure this is a valid tax class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxclassnum')
    || $self->ut_text('taxclass')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=cut

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data { # class method
  my ($class, %opts) = @_;

  my $sth = dbh->prepare('
    SELECT DISTINCT taxclass
      FROM cust_main_county
        LEFT JOIN part_pkg_taxclass USING ( taxclass )
      WHERE taxclassnum IS NULL
        AND taxclass IS NOT NULL
  ') or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  my %taxclass = map { $_->[0] => 1 } @{$sth->fetchall_arrayref};
  my @taxclass = grep $_, keys %taxclass;

  foreach my $taxclass ( @taxclass ) {

    my $part_pkg_taxclass = new FS::part_pkg_taxclass ( {
      'taxclass' => $taxclass,
    } );
    my $error = $part_pkg_taxclass->insert;
    die $error if $error;

  }

}

=head1 BUGS

Other tables (cust_main_county, part_pkg, agent_payment_gateway) have a text
taxclass instead of a key to this table.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

