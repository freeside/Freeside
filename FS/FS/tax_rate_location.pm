package FS::tax_rate_location;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbh );
use FS::Misc qw( csv_from_fixed );

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

An FS::tax_rate_location object represents a tax jurisdiction.  The only
functional field is "geocode", a foreign key to tax rates (L<FS::tax_rate>) 
that apply in the jurisdiction.  The city, county, state, and country fields 
are provided for description and reporting.

FS::tax_rate_location inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item taxratelocationnum - Primary key (assigned automatically for new 
tax_rate_locations)

=item data_vendor - The tax data vendor ('cch' or 'billsoft').

=item geocode - A unique geographic location code provided by the data vendor

=item city - City

=item county -  County

=item state - State (2-letter code)

=item country - Country (2-letter code, optional)

=item disabled - If 'Y' this record is no longer active.

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

  my $t;
  $t = qsearchs( 'tax_rate_location',
                 { disabled => '',
                   ( map { $_ => $self->$_ } qw( data_vendor geocode ) ),
                 },
               )
    unless $self->disabled;

  $t = $self->by_key( $self->taxratelocationnum )
    if ( !$t && $self->taxratelocationnum );

  return "geocode ". $self->geocode. " already in use for this vendor"
    if ( $t && $t->taxratelocationnum != $self->taxratelocationnum );

  return "may only be disabled"
    if ( $t && scalar( grep { $t->$_ ne $self->$_ } 
                       grep { $_ ne 'disabled' }
                       $self->fields
                     )
       );

  $self->SUPER::check;
}

=item find_or_insert

Finds an existing, non-disabled tax jurisdiction matching the data_vendor 
and geocode fields. If there is one, updates its city, county, state, and
country to match this record.  If there is no existing record, inserts this 
record.

=cut

sub find_or_insert {
  my $self = shift;
  my $existing = qsearchs('tax_rate_location', {
      disabled    => '',
      data_vendor => $self->data_vendor,
      geocode     => $self->geocode
  });
  if ($existing) {
    my $update = 0;
    foreach (qw(city county state country)) {
      if ($self->get($_) ne $existing->get($_)) {
        $update++;
      }
    }
    $self->set(taxratelocationnum => $existing->taxratelocationnum);
    if ($update) {
      return $self->replace($existing);
    } else {
      return;
    }
  } else {
    return $self->insert;
  }
}

=back

=head1 CLASS METHODS

=item location_sql KEY => VALUE, ...

Returns an SQL fragment identifying matching tax_rate_location /
cust_bill_pkg_tax_rate_location records.

Parameters are county, state, city and locationtaxid

=cut

sub location_sql {
  my($class, %param) = @_;

  my %pn = (
   'city'          => 'tax_rate_location.city',
   'county'        => 'tax_rate_location.county',
   'state'         => 'tax_rate_location.state',
   'locationtaxid' => 'cust_bill_pkg_tax_rate_location.locationtaxid',
  );

  my %ph = map { $pn{$_} => dbh->quote($param{$_}) } keys %pn;

  join( ' AND ',
    map { "( $_ = $ph{$_} OR $ph{$_} = '' AND $_ IS NULL)" } keys %ph
  );

}

=back

=head1 SUBROUTINES

=over 4

=item batch_import HASHREF, JOB

Starts importing tax_rate_location records from a file.  HASHREF must contain
'filehandle' (an open handle to the input file) and 'format' (one of 'cch',
'cch-fixed', 'cch-update', 'cch-fixed-update', or 'billsoft').  JOB is an
L<FS::queue> object to receive progress messages.

=cut

# XXX move this into TaxEngine modules at some point

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
  if ( $job || scalar(@column_callbacks) ) { # this makes zero sense
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

        $hash->{disabled} = '';
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

  } elsif ( $format eq 'billsoft' ) {
    @fields = ( qw( geocode alt_location country state county city ), '', '' );

    $hook = sub {
      my $hash = shift;
      if ($hash->{alt_location}) {
        # don't import these; the jurisdiction should be named using its 
        # primary city
        %$hash = ();
        return;
      }

      $hash->{data_vendor} = 'billsoft';
      # unlike cust_tax_location, keep the whole-country and whole-state 
      # rows, but strip the whitespace
      $hash->{county} =~ s/^ //g;
      $hash->{state} =~ s/^ //g;
      $hash->{country} =~ s/^ //g;
      $hash->{city} =~ s/[^\w ]//g; # remove asterisks and other bad things
      $hash->{country} = substr($hash->{country}, 0, 2);
      '';
    }

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
          int( 100 * $imported / $count ) .
          ',Creating tax jurisdiction records'
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
      return "Unexpected trailing columns in line (wrong format?) importing tax-rate_location: $line";
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
        return "can't insert tax_rate_location for $line: $error";
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

