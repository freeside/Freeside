package FS::cust_tax_location;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::Misc qw ( csv_from_fixed );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_tax_location - Object methods for cust_tax_location records

=head1 SYNOPSIS

  use FS::cust_tax_location;

  $record = new FS::cust_tax_location \%hash;
  $record = new FS::cust_tax_location { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_tax_location object represents a classification rule for
determining a tax region code ('geocode') for a service location.  These
records are used when editing customer locations to help the user choose the
correct tax jurisdiction code.  The jurisdiction codes are actually defined
in L<FS::tax_rate_location>, and appear directly in records in
L<FS::tax_rate>.

FS::cust_tax_location is used in tax calculation (for CCH) to determine 
"implied" geocodes for customers and locations that have a complete U.S.
ZIP+4 code and thus can be exactly placed in a jurisdiction.  For those that
don't, the user is expected to choose the geocode when entering the customer
record.

FS::cust_tax_location inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item custlocationnum - primary key

=item data_vendor - a tax data vendor and "style" of record

=item country - the two-letter country code

=item state - the two-letter state code (though CCH uses this differently;
see QUIRKS)

=item zip - an exact zip code (again, see QUIRKS)

=item ziplo -  the lower bound of the zip code range (requires zip to be null)

=item ziphi - the upper bound of the zip code range (requires zip to be null)

=item plus4lo - the lower bound of the last 4 zip code digits

=item plus4hi - the upper bound of the last 4 zip code digits

=item default_location - 'Y' when this record represents the default.  The UI
will list default locations before non-default locations.

=item geocode - the foreign key into L<FS::part_pkg_tax_rate>, 
L<FS::tax_rate>, L<FS::tax_rate_location>, etc.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cust_tax_location.  To add the cust_tax_location to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_tax_location'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid cust_tax_location.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('custlocationnum')
    || $self->ut_text('data_vendor')
    || $self->ut_textn('city')
    || $self->ut_textn('postalcity')
    || $self->ut_textn('county')
    || $self->ut_text('state')
    || $self->ut_numbern('plus4hi')
    || $self->ut_numbern('plus4lo')
    || $self->ut_enum('default_location', [ '', 'Y' ] )
    || $self->ut_enum('cityflag', [ '', 'I', 'O', 'B' ] )
    || $self->ut_alpha('geocode')
  ;
  if ( $self->country ) {
    $error ||= $self->ut_country('country')
           ||  $self->ut_zip('ziphi', $self->country)
           ||  $self->ut_zip('ziplo', $self->country);
  }
  return $error if $error;

  if ($self->state eq 'CN' && $self->data_vendor eq 'cch-zip' ) {
    $error = "Illegal canadian zip"
     unless $self->zip =~ /^[A-Z]$/;
  } elsif ($self->state =~ /^E([B-DFGILNPR-UW])$/ && $self->data_vendor eq 'cch-zip' ) {
    $error = "Illegal european zip"
     unless $self->zip =~ /^E$1$/;
  } elsif ($self->data_vendor =~ /^cch/) {
    $error = $self->ut_numbern('zip', $self->state eq 'CN' ? 'CA' : 'US');
  }
  return $error if $error;

  $self->SUPER::check;
}

# annoyingly incompatible with FS::Record::batch_import.

sub batch_import {
  my ($param, $job) = @_;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my $imported = 0;
  my @fields;
  my $hook;

  my @column_lengths = ();
  my @column_callbacks = ();
  if ( $format =~ /^cch-fixed/ ) {
    $format =~ s/-fixed//;
    my $f = $format;
    my $update = 0;
    $f =~ s/-update// && ($update = 1);
    if ($f eq 'cch') {
      push @column_lengths, qw( 5 2 4 4 10 1 );
    } elsif ( $f eq 'cch-zip' ) {
      push @column_lengths, qw( 5 28 25 2 28 5 1 1 10 1 2 );
    } else {
      return "Unknown format: $format";
    }
    push @column_lengths, 1 if $update;
  }

  my $line;
  my ( $count, $last, $min_sec ) = (0, time, 5); #progressbar
  if ( $job || scalar(@column_lengths) ) {
    my $error = csv_from_fixed(\$fh, \$count, \@column_lengths);
    return $error if $error;
  }

  if ( $format eq 'cch' || $format eq 'cch-update' ) {
    @fields = qw( zip state plus4lo plus4hi geocode default_location );
    push @fields, 'actionflag' if $format eq 'cch-update';

    $imported++ if $format eq 'cch-update'; #empty file ok
    
    $hook = sub {
      my $hash = shift;

      $hash->{'data_vendor'} = 'cch';
      $hash->{'default_location'} =~ s/ //g;

      if (exists($hash->{actionflag}) && $hash->{actionflag} eq 'D') {
        delete($hash->{actionflag});

        my @cust_tax_location = qsearch('cust_tax_location', $hash);
        return "Can't find cust_tax_location to delete: ".
               join(" ", map { "$_ => ". $hash->{$_} } @fields)
          unless scalar(@cust_tax_location) || $param->{'delete_only'} ;

        foreach my $cust_tax_location (@cust_tax_location) {
          my $error = $cust_tax_location->delete;
          return $error if $error;
        }

        delete($hash->{$_}) foreach (keys %$hash);
      }

      delete($hash->{'actionflag'});

      '';
      
    };

  } elsif ( $format eq 'cch-zip' || $format eq 'cch-update-zip' ) {
    @fields = qw( zip city county state postalcity countyfips countydef default_location geocode cityflag unique );
    push @fields, 'actionflag' if $format eq 'cch-update-zip';

    $imported++ if $format eq 'cch-update'; #empty file ok
    
    $hook = sub {
      my $hash = shift;

      $hash->{'data_vendor'} = 'cch-zip';
      delete($hash->{$_}) foreach qw( countyfips countydef unique );

      $hash->{'cityflag'} =~ s/ //g;
      $hash->{'default_location'} =~ s/ //g;

      if (exists($hash->{actionflag}) && $hash->{actionflag} eq 'D') {
        delete($hash->{actionflag});

        my @cust_tax_location = qsearch('cust_tax_location', $hash);
        return "Can't find cust_tax_location to delete: ".
               join(" ", map { "$_ => ". $hash->{$_} } @fields)
          unless scalar(@cust_tax_location) || $param->{'delete_only'} ;

        foreach my $cust_tax_location (@cust_tax_location) {
          my $error = $cust_tax_location->delete;
          return $error if $error;
        }

        delete($hash->{$_}) foreach (keys %$hash);
      }

      delete($hash->{'actionflag'});

      '';
      
    };

  } elsif ( $format eq 'billsoft' ) {

    @fields = qw( geocode alt_location country state county city 
                  ziplo ziphi );
    $hook = sub {
      my $hash = shift;
      $hash->{data_vendor} = 'billsoft';
      $hash->{default_location} = ($hash->{alt_location} ? '' : 'Y');
      $hash->{city} =~ s/[^\w ]//g; # remove asterisks and other bad things
      $hash->{country} = substr($hash->{country}, 0, 2);
      if (    $hash->{state} =~ /^ *$/
           or $hash->{county} =~ /^ *$/
           or $hash->{country} !~ /^US|CA$/ ) {
        # remove whole-country rows, whole-state rows, and non-CAN/USA rows
        %$hash = ();
      }
      '';
    };

  } elsif ( $format eq 'extended' ) {
    die "unimplemented\n";
    @fields = qw( );
  } else {
    die "unknown format $format";
  }

  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;

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
          int( 100 * $imported / $count ). ",Importing tax locations"
        );
        die $error if $error;
        $last = time;
      }
    }

    my @columns = $csv->fields();

    my %cust_tax_location = ( 'data_vendor' => $format );;
    foreach my $field ( @fields ) {
      $cust_tax_location{$field} = shift @columns; 
    }
    if ( scalar( @columns ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Unexpected trailing columns in line (wrong format?) importing cust_tax_location: $line";
    }

    my $error = &{$hook}(\%cust_tax_location);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    # $hook can delete the contents of the hash to prevent the row from 
    # being inserted
    next unless scalar(keys %cust_tax_location);

    my $cust_tax_location = new FS::cust_tax_location( \%cust_tax_location );
    $error = $cust_tax_location->insert;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert cust_tax_location for $line: $error";
    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless ( $imported || $format =~ /^cch-update/ );

  ''; #no error

}

=back

=head1 SUBROUTINES

=over 4

=item process_batch_import JOB, PARAMS

Starts a batch import given JOB (an L<FS::queue>) and PARAMS (a 
Base64-Storable hash).  PARAMS should contain 'format' and 'uploaded_files'.

Currently only usable for Billsoft imports; CCH's agglomeration of update
files need to be imported through L<FS::tax_rate::process_batch_import>.

=cut

sub process_batch_import {
  my $job = shift;
  my $param = shift;

  my $files = $param->{'uploaded_files'};

  my ($file) = ($files =~ /^zipfile:(.*)$/)
    or die "No files provided.\n";

  my $dir = $FS::UID::cache_dir . '/cache.' . $FS::UID::datasrc;
  open ( $param->{'filehandle'}, '<', "$dir/$file" )
    or die "unable to open '$file': $!\n";

  my $error = batch_import($param, $job);
  die $error if $error;
}

=back

=head1 QUIRKS

CCH doesn't have a "country" field; for addresses in Canada it uses state 
= 'CN', and zip = the one-letter postal code prefix for the province.  Or
maybe that's just our CCH implementation.  This doesn't apply to Billsoft,
and shouldn't apply to any other tax vendor that may somehow be implemented.

CCH also has two styles of records in this table: cch and cch-zip.  cch 
records define a unique 

=head1 BUGS

CCH clutter.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

