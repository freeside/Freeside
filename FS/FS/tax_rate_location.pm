package FS::tax_rate_location;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbh );

=head1 NAME

FS::tax_rate_location - Object methods for tax_rate_location records

=head1 SYNOPSIS

  use FS::tax_rate_location;

  $record = new FS::tax_rate_location \%hash;
  $record = new FS::tax_rate_location { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tax_rate_location object represents an example.  FS::tax_rate_location inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item taxratelocationnum

Primary key (assigned automatically for new tax_rate_locations)

=item data_vendor

The tax data vendor

=item geocode

A unique geographic location code provided by the data vendor

=item city

City

=item county

County

=item state

State

=item disabled

If 'Y' this record is no longer active.


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax rate location.  To add the record to the database, see
 L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'tax_rate_location'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

sub delete {
  return "Can't delete tax rate locations.  Set disable to 'Y' instead.";
  # check that it is unused in any cust_bill_pkg_tax_location records instead?
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid tax rate location.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxratelocationnum')
    || $self->ut_textn('data_vendor')
    || $self->ut_alpha('geocode')
    || $self->ut_textn('city')
    || $self->ut_textn('county')
    || $self->ut_textn('state')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  my $t = qsearchs( 'tax_rate_location',
                    { map { $_ => $self->$_ } qw( data_vendor geocode ) },
                  );

  return "geocode already in use for this vendor"
    if ( $t && $t->taxratelocationnum != $self->taxratelocationnum );

  return "may only be disabled"
    if ( $t && scalar( grep { $t->$_ ne $self->$_ } 
                       grep { $_ ne 'disabled' }
                       $self->fields
                     )
       );

  $self->SUPER::check;
}

=back

=head1 SUBROUTINES

=over 4

=item batch_import

=cut

sub batch_import {
  my ($param, $job) = @_;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my %insert = ();
  my %delete = ();

  my @fields;
  my $hook;

  my @column_lengths = ();
  my @column_callbacks = ();
  if ( $format eq 'cch-fixed' || $format eq 'cch-fixed-update' ) {
    $format =~ s/-fixed//;
    my $trim = sub { my $r = shift; $r =~ s/^\s*//; $r =~ s/\s*$//; $r };
    push @column_lengths, qw( 28 25 2 10 );
    push @column_lengths, 1 if $format eq 'cch-update';
    push @column_callbacks, $trim foreach (@column_lengths);
  }

  my $line;
  my ( $count, $last, $min_sec ) = (0, time, 5); #progressbar
  if ( $job || scalar(@column_callbacks) ) {
    my $error =
      csv_from_fixed(\$fh, \$count, \@column_lengths, \@column_callbacks);
    return $error if $error;
  }

  if ( $format eq 'cch' || $format eq 'cch-update' ) {
    @fields = qw( city county state geocode );
    push @fields, 'actionflag' if $format eq 'cch-update';

    $hook = sub {
      my $hash = shift;

      $hash->{'data_vendor'} ='cch';

      if (exists($hash->{'actionflag'}) && $hash->{'actionflag'} eq 'D') {
        delete($hash->{actionflag});

        $hash->{deleted} = '';
        my $tax_rate_location = qsearchs('tax_rate_location', $hash);
        return "Can't find tax_rate_location to delete: ".
               join(" ", map { "$_ => ". $hash->{$_} } @fields)
          unless $tax_rate_location;

        $tax_rate_location->disabled('Y');
        my $error = $tax_rate_location->replace;
        return $error if $error;

        delete($hash->{$_}) foreach (keys %$hash);
      }

      delete($hash->{'actionflag'});

      '';

    };

  } elsif ( $format eq 'extended' ) {
    die "unimplemented\n";
    @fields = qw( );
    $hook = sub {};
  } else {
    die "unknown format $format";
  }

  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;

  my $imported = 0;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  while ( defined($line=<$fh>) ) {
    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count )
        );
        die $error if $error;
        $last = time;
      }
    }

    my @columns = $csv->fields();

    my %tax_rate_location = ();
    foreach my $field ( @fields ) {
      $tax_rate_location{$field} = shift @columns;
    }
    if ( scalar( @columns ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Unexpected trailing columns in line (wrong format?): $line";
    }

    my $error = &{$hook}(\%tax_rate_location);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    if (scalar(keys %tax_rate_location)) { #inserts only

      my $tax_rate_location = new FS::tax_rate_location( \%tax_rate_location );
      $error = $tax_rate_location->insert;

      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't insert tax_rate for $line: $error";
      }

    }

    $imported++;

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless ($imported || $format eq 'cch-update');

  ''; #no error

}

=head1 BUGS

Currently somewhat specific to CCH supplied data.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

