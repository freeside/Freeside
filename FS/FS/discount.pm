package FS::discount;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::discount - Object methods for discount records

=head1 SYNOPSIS

  use FS::discount;

  $record = new FS::discount \%hash;
  $record = new FS::discount { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::discount object represents a discount definition.  FS::discount inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item discountnum

primary key

=item name

name

=item amount

amount

=item percent

percent

=item months

months

=item disabled

disabled

=item setup - apply discount to setup fee (not just to recurring fee)

If the discount is based on a percentage, then the % will be applied to the
setup and recurring portions. 

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new discount.  To add the discount to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'discount'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid discount.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  if ( $self->_type eq 'Select discount type' ) {
    return 'Please select a discount type';
  } elsif ( $self->_type eq 'Amount' ) {
    $self->percent('0');
    return 'Amount must be greater than 0' unless $self->amount > 0;
  } elsif ( $self->_type eq 'Percentage' ) {
    $self->amount('0.00');
    return 'Percentage must be greater than 0' unless $self->percent > 0;
  }

  my $error = 
    $self->ut_numbern('discountnum')
    || $self->ut_textn('name')
    || $self->ut_money('amount')
    || $self->ut_float('percent') #actually decimal, but this will do
    || $self->ut_floatn('months') #actually decimal, but this will do
    || $self->ut_enum('disabled', [ '', 'Y' ])
    || $self->ut_enum('setup', [ '', 'Y' ])
  ;
  return $error if $error;

  #discourage non-integer months for package discounts
  if ($self->discountnum) {
    my $sql =
      "SELECT count(*) FROM part_pkg_discount WHERE part_pkg_discount.discountnum = ".
      $self->discountnum;

    my $count = $self->scalar_sql($sql); 
    return "months must be integers greater than 1"
      if ( $count && ($self->ut_number('months') || $self->months < 2) );
  }
    
  $self->SUPER::check;
}

=item description_short

=item description

Returns a text description incorporating the amount, percent and months fields.

description_short omits term information

=cut

sub description_short {
  my $self = shift;

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';  

  my $desc = $self->name ? $self->name.': ' : '';
  $desc .= $money_char. sprintf('%.2f/month ', $self->amount)
    if $self->amount > 0;

  ( my $percent = $self->percent ) =~ s/\.0+$//;
  $percent =~ s/(\.\d*[1-9])0+$/$1/;
  $desc .= $percent. '% '
    if $self->percent > 0;

  $desc;
}

sub description {
  my $self = shift;
  my $desc = $self->description_short;

  ( my $months = $self->months ) =~ s/\.0+$//;
  $months =~ s/(\.\d*[1-9])0+$/$1/;
  $desc .= " for $months months" if $months;

  $desc .= ', applies to setup' if $self->setup;

  $desc;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_pkg_discount>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

