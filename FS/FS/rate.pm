package FS::rate;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::rate_detail;

@ISA = qw(FS::Record);

=head1 NAME

FS::rate - Object methods for rate records

=head1 SYNOPSIS

  use FS::rate;

  $record = new FS::rate \%hash;
  $record = new FS::rate { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate object represents an rate plan.  FS::rate inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item ratenum - primary key

=item ratename

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new rate plan.  To add the rate plan to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate'; }

=item insert [ , OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

Currently available options are: I<rate_detail>

If I<rate_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their ratenum field set and will be inserted after this
record.

=cut

sub insert {
  my $self = shift;
  my %options = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $options{'rate_detail'} ) {
    foreach my $rate_detail ( @{$options{'rate_detail'}} ) {
      $rate_detail->ratenum($self->ratenum);
      $error = $rate_detail->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}



=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD [ , OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently available options are: I<rate_detail>

If I<rate_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their ratenum field set and will be inserted after this
record.  Any existing rate_detail records associated with this record will be
deleted.

=cut

sub replace {
  my ($new, $old) = (shift, shift);
  my %options = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @old_rate_detail = ();
  @old_rate_detail = $old->rate_detail if $options{'rate_detail'};

  my $error = $new->SUPER::replace($old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $old_rate_detail ( @old_rate_detail ) {
    my $error = $old_rate_detail->delete;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $rate_detail ( @{$options{'rate_detail'}} ) {
    $rate_detail->ratenum($new->ratenum);
    $error = $rate_detail->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid rate plan.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error =
       $self->ut_numbern('ratenum')
    || $self->ut_text('ratename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item dest_detail REGIONNUM | RATE_REGION_OBJECTD

Returns the rate detail (see L<FS::rate_detail>) for this rate to the
specificed destination.

=cut

sub dest_detail {
  my $self = shift;
  my $regionnum = ref($_[0]) ? shift->regionnum : shift;
  qsearchs( 'rate_detail', { 'ratenum'        => $self->ratenum,
                             'dest_regionnum' => $regionnum,     } );
}

=item rate_detail

Returns all region-specific details  (see L<FS::rate_detail>) for this rate.

=cut

sub rate_detail {
  my $self = shift;
  qsearch( 'rate_detail', { 'ratenum' => $self->ratenum } );
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

