package FS::rate_region;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::rate_prefix;
use FS::rate_detail;

@ISA = qw(FS::Record);

=head1 NAME

FS::rate_region - Object methods for rate_region records

=head1 SYNOPSIS

  use FS::rate_region;

  $record = new FS::rate_region \%hash;
  $record = new FS::rate_region { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_region object represents an call rating region.  FS::rate_region
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item regionnum - primary key

=item regionname

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new region.  To add the region to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_region'; }

=item insert [ , OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

Currently available options are: I<rate_prefix> and I<dest_detail>

If I<rate_prefix> is set to an array reference of FS::rate_prefix objects, the
objects will have their regionnum field set and will be inserted after this
record.

If I<dest_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their dest_regionnum field set and will be inserted after
this record.


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

  if ( $options{'rate_prefix'} ) {
    foreach my $rate_prefix ( @{$options{'rate_prefix'}} ) {
      $rate_prefix->regionnum($self->regionnum);
      $error = $rate_prefix->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  if ( $options{'dest_detail'} ) {
    foreach my $rate_detail ( @{$options{'dest_detail'}} ) {
      $rate_detail->dest_regionnum($self->regionnum);
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

Currently available options are: I<rate_prefix> and I<dest_detail>

If I<rate_prefix> is set to an array reference of FS::rate_prefix objects, the
objects will have their regionnum field set and will be inserted after this
record.  Any existing rate_prefix records associated with this record will be
deleted.

If I<dest_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their dest_regionnum field set and will be inserted after
this record.  Any existing rate_detail records associated with this record will
be deleted.

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

  my @old_rate_prefix = ();
  @old_rate_prefix = $old->rate_prefix if $options{'rate_prefix'};
  my @old_dest_detail = ();
  @old_dest_detail = $old->dest_detail if $options{'dest_detail'};

  my $error = $new->SUPER::replace($old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $old_rate_prefix ( @old_rate_prefix ) {
    my $error = $old_rate_prefix->delete;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  foreach my $old_dest_detail ( @old_dest_detail ) {
    my $error = $old_dest_detail->delete;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $rate_prefix ( @{$options{'rate_prefix'}} ) {
    $rate_prefix->regionnum($new->regionnum);
    $error = $rate_prefix->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  foreach my $rate_detail ( @{$options{'dest_detail'}} ) {
    $rate_detail->dest_regionnum($new->regionnum);
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

Checks all fields to make sure this is a valid region.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error =
       $self->ut_numbern('regionnum')
    || $self->ut_text('regionname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate_prefix

Returns all prefixes (see L<FS::rate_prefix>) for this region.

=cut

sub rate_prefix {
  my $self = shift;

  sort {    $a->countrycode cmp $b->countrycode
         or $a->npa         cmp $b->npa
         or $a->nxx         cmp $b->nxx
       }
       qsearch( 'rate_prefix', { 'regionnum' => $self->regionnum } );
}

=item dest_detail

Returns all rate details (see L<FS::rate_detail>) for this region as a
destionation.

=cut

sub dest_detail {
  my $self = shift;
  qsearch( 'rate_detail', { 'dest_regionnum' => $self->regionnum, } );
}

=item prefixes_short

Returns a string representing all the prefixes for this region.

=cut

sub prefixes_short {
  my $self = shift;

  my $countrycode = '';
  my $out = '';

  foreach my $rate_prefix ( $self->rate_prefix ) {
    if ( $countrycode ne $rate_prefix->countrycode ) {
      $out =~ s/, $//;
      $countrycode = $rate_prefix->countrycode;
      $out.= " +$countrycode ";
    }
    my $npa = $rate_prefix->npa;
    if ( $countrycode eq '1' ) {
      $out .= '('. substr( $npa, 0, 3 ). ')';
      $out .= ' '. substr( $npa, 3 ) if length($npa) > 3;
    } else {
      $out .= $rate_prefix->npa;
    }
    $out .= ' '. $rate_prefix->nxx if $rate_prefix->nxx;
    $out .= ', ';
  }
  $out =~ s/, $//;

  $out;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

