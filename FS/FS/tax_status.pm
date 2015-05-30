package FS::tax_status;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

our %initial_data;

=head1 NAME

FS::tax_status - Object methods for tax_status records

=head1 SYNOPSIS

  use FS::tax_status;

  $record = new FS::tax_status \%hash;
  $record = new FS::tax_status { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tax_status object represents a customer tax status for use with
an external tax table.  FS::tax_status inherits from FS::Record.  The 
following fields are currently supported:

=over 4

=item taxstatusnum

primary key

=item data_vendor

Data vendor name (corresponds to the value of the C<taxproduct> config 
variable.)

=item taxstatus

The data vendor's name or code for the tax status.

=item description

Description for use in the Freeside UI.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax status.  To add the record to the database, see L<"insert">.

=cut

sub table { 'tax_status'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxstatusnum')
    || $self->ut_textn('data_vendor')
    || $self->ut_text('taxstatus')
    || $self->ut_text('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub _upgrade_data {
  my $self = shift;
  my $error;
  foreach my $data_vendor ( keys %initial_data ) {
    my $status_hash = $initial_data{$data_vendor};
    foreach my $taxstatus (sort keys %$status_hash) {
      my $description = $status_hash->{$taxstatus};
      my $tax_status;
      if ($tax_status = qsearchs('tax_status', {
            data_vendor => $data_vendor,
            taxstatus   => $taxstatus
        }))
      {
        if ($tax_status->description ne $description) {
          $tax_status->set(description => $description);
          $error = $tax_status->replace;
        }
        # else it's already correct
      } else {
        $tax_status = FS::tax_status->new({
            data_vendor => $data_vendor,
            taxstatus   => $taxstatus,
            description => $description
        });
        $error = $tax_status->insert;
      }
      die $error if $error;
    }
  }
}

%initial_data = (
  'avalara' => {
    'A' => 'Federal Government',
    'B' => 'State/Local Government',
    'C' => 'Tribal Government',
    'D' => 'Foreign Diplomat',
    'E' => 'Charitable Organization',
    'F' => 'Religious/Education',
    'G' => 'Resale',
    'H' => 'Agricultural Production',
    'I' => 'Industrial Production',
    'J' => 'Direct Pay Permit',
    'K' => 'Direct Mail',
    'L' => 'Other',
    'M' => 'Local Government',
    # P, Q, R: Canada, not yet supported
    # MED1/MED2: totally irrelevant to our users
  },
  suretax => {
    'R' => 'Residential',
    'B' => 'Business',
    'I' => 'Industrial',
    'L' => 'Lifeline',
  },
);

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

