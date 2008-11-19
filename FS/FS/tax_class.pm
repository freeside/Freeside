package FS::tax_class;

use strict;
use vars qw( @ISA );
use FS::UID qw(dbh);
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( csv_from_fixed );

@ISA = qw(FS::Record);

=head1 NAME

FS::tax_class - Object methods for tax_class records

=head1 SYNOPSIS

  use FS::tax_class;

  $record = new FS::tax_class \%hash;
  $record = new FS::tax_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tax_class object represents a tax class.  FS::tax_class
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item taxclassnum

Primary key

=item data_vendor

Vendor of the tax data

=item taxclass

Tax class

=item description

Human readable description of the tax class

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax class.  To add the tax class to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'tax_class'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a tax class which has tax rates!"
    if qsearch( 'tax_rate', { 'taxclassnum' => $self->taxclassnum } );

  return "Can't delete a tax class which has package tax rates!"
    if qsearch( 'part_pkg_taxrate', { 'taxclassnum' => $self->taxclassnum } );

  return "Can't delete a tax class which has package tax rates!"
    if qsearch( 'part_pkg_taxrate', { 'taxclassnumtaxed' => $self->taxclassnum } );

  return "Can't delete a tax class which has package tax overrides!"
    if qsearch( 'part_pkg_taxoverride', { 'taxclassnum' => $self->taxclassnum } );

  $self->SUPER::delete(@_);
  
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid tax class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxclassnum')
    || $self->ut_text('taxclass')
    || $self->ut_textn('data_vendor')
    || $self->ut_textn('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item batch_import

Loads part_pkg_taxrate records from an external CSV file.  If there is
an error, returns the error, otherwise returns false. 

=cut 

sub batch_import {
  my ($param, $job) = @_;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my @fields;
  my $hook;
  my $endhook;
  my $data = {};
  my $imported = 0;
  my $dbh = dbh;

  my @column_lengths = ();
  my @column_callbacks = ();
  if ( $format eq 'cch-fixed' || $format eq 'cch-fixed-update' ) {
    $format =~ s/-fixed//;
    push @column_lengths, qw( 8 10 3 2 2 10 100 );
    push @column_lengths, 1 if $format eq 'cch-update';
  }

  my $line;
  my ( $count, $last, $min_sec ) = (0, time, 5); #progressbar
  if ( $job || scalar(@column_callbacks) ) {
    my $error = csv_from_fixed(\$fh, \$count, \@column_lengths);
    return $error if $error;
  }

  if ( $format eq 'cch' || $format eq 'cch-update' ) {
    @fields = qw( table name pos length number value description );
    push @fields, 'actionflag' if $format eq 'cch-update';

    $hook = sub { 
      my $hash = shift;

      if ($hash->{'table'} eq 'DETAIL') {
        push @{$data->{'taxcat'}}, [ $hash->{'value'}, $hash->{'description'} ]
          if ($hash->{'name'} eq 'TAXCAT' &&
             (!exists($hash->{actionflag}) || $hash->{actionflag} eq 'I') );

        push @{$data->{'taxtype'}}, [ $hash->{'value'}, $hash->{'description'} ]
          if ($hash->{'name'} eq 'TAXTYPE' &&
             (!exists($hash->{actionflag}) || $hash->{actionflag} eq 'I') );

        if (exists($hash->{actionflag}) && $hash->{actionflag} eq 'D') {
          my $name = $hash->{'name'};
          my $value = $hash->{'value'};
          return "Bad value for $name: $value"
            unless $value =~ /^\d+$/;

          if ($name eq 'TAXCAT' || $name eq 'TAXTYPE') {
            my @tax_class = qsearch( 'tax_class',
                                     { 'data_vendor' => 'cch' },
                                     '',
                                     "AND taxclass LIKE '".
                                       ($name eq 'TAXTYPE' ? $value : '%').":".
                                       ($name eq 'TAXCAT' ? $value : '%')."'",
                                   );
            foreach (@tax_class) {
              my $error = $_->delete;
              return $error if $error;
            }
          }
        }

      }

      delete($hash->{$_})
        for qw( data_vendor table name pos length number value description );
      delete($hash->{actionflag}) if exists($hash->{actionflag});

      '';

    };

    $endhook = sub { 

      my $sql = "SELECT DISTINCT ".
         "substring(taxclass from 1 for position(':' in taxclass)-1),".
         "substring(description from 1 for position(':' in description)-1) ".
         "FROM tax_class WHERE data_vendor='cch'";

      my $sth = $dbh->prepare($sql) or die $dbh->errstr;
      $sth->execute or die $sth->errstr;
      my @old_types = @{$sth->fetchall_arrayref};

      $sql = "SELECT DISTINCT ".
         "substring(taxclass from position(':' in taxclass)+1),".
         "substring(description from position(':' in description)+1) ".
         "FROM tax_class WHERE data_vendor='cch'";

      $sth = $dbh->prepare($sql) or die $dbh->errstr;
      $sth->execute or die $sth->errstr;
      my @old_cats = @{$sth->fetchall_arrayref};

      my $catcount  = exists($data->{'taxcat'})  ? scalar(@{$data->{'taxcat'}})
                                                 : 0;
      my $typecount = exists($data->{'taxtype'}) ? scalar(@{$data->{'taxtype'}})
                                                 : 0;

      my $count = scalar(@old_types) * $catcount
                + $typecount * (scalar(@old_cats) + $catcount);

      $imported = 1 if $format eq 'cch-update';  #empty file ok

      foreach my $type (@old_types) {
        foreach my $cat (@{$data->{'taxcat'}}) {

          if ( $job ) {  # progress bar
            if ( time - $min_sec > $last ) {
              my $error = $job->update_statustext(
                int( 100 * $imported / $count )
              );
              die $error if $error;
              $last = time;
            }
          }

          my $tax_class =
            new FS::tax_class( { 'data_vendor' => 'cch',
                                 'taxclass'    => $type->[0].':'.$cat->[0],
                                 'description' => $type->[1].':'.$cat->[1],
                             } );
          my $error = $tax_class->insert;
          return $error if $error;
          $imported++;
        }
      }

      foreach my $type (@{$data->{'taxtype'}}) {
        foreach my $cat (@old_cats, @{$data->{'taxcat'}}) {

          if ( $job ) {  # progress bar
            if ( time - $min_sec > $last ) {
              my $error = $job->update_statustext(
                int( 100 * $imported / $count )
              );
              die $error if $error;
              $last = time;
            }
          }

          my $tax_class =
            new FS::tax_class( { 'data_vendor' => 'cch',
                                 'taxclass'    => $type->[0].':'.$cat->[0],
                                 'description' => $type->[1].':'.$cat->[1],
                             } );
          my $error = $tax_class->insert;
          return $error if $error;
          $imported++;
        }
      }

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

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  
  while ( defined($line=<$fh>) ) {

    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count )
        );
        die $error if $error;
        $last = time;
      }
    }

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();

    my %tax_class = ( 'data_vendor' => $format );
    foreach my $field ( @fields ) {
      $tax_class{$field} = shift @columns; 
    }
    if ( scalar( @columns ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Unexpected trailing columns in line (wrong format?): $line";
    }

    my $error = &{$hook}(\%tax_class);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    next unless scalar(keys %tax_class);

    my $tax_class = new FS::tax_class( \%tax_class );
    $error = $tax_class->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert tax_class for $line: $error";
    }

    $imported++;
  }

  my $error = &{$endhook}();
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't insert tax_class for $line: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty File!" unless $imported;

  ''; #no error

}

=back

=head1 BUGS

  batch_import does not handle mixed I and D records in the same file for
  format cch-update

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;


