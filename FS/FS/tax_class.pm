package FS::tax_class;

use strict;
use vars qw( @ISA );
use FS::UID qw(dbh);
use FS::Record qw( qsearch qsearchs );

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
  my $param = shift;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my @fields;
  my $hook;
  my $endhook;
  my $data = {};
  my $imported = 0;

  if ( $format eq 'cch' ) {
    @fields = qw( table name pos number length value description );

    $hook = sub { 
      my $hash = shift;

      if ($hash->{'table'} eq 'DETAIL') {
        push @{$data->{'taxcat'}}, [ $hash->{'value'}, $hash->{'description'} ]
          if $hash->{'name'} eq 'TAXCAT';

        push @{$data->{'taxtype'}}, [ $hash->{'value'}, $hash->{'description'} ]
          if $hash->{'name'} eq 'TAXTYPE';
      }

      delete($hash->{$_})
        for qw( data_vendor table name pos number length value description );

      '';

    };

    $endhook = sub { 
      foreach my $type (@{$data->{'taxtype'}}) {
        foreach my $cat (@{$data->{'taxcat'}}) {
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
  my $dbh = dbh;
  
  my $line;
  while ( defined($line=<$fh>) ) {
    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();

    my %tax_class = ( 'data_vendor' => $format );
    foreach my $field ( @fields ) {
      $tax_class{$field} = shift @columns; 
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

  return "Empty file!" unless $imported;

  ''; #no error

}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;


