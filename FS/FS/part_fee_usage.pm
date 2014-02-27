package FS::part_fee_usage;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;

=head1 NAME

FS::part_fee_usage - Object methods for part_fee_usage records

=head1 SYNOPSIS

  use FS::part_fee_usage;

  $record = new FS::part_fee_usage \%hash;
  $record = new FS::part_fee_usage { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_fee_usage object is the part of a processing fee definition 
(L<FS::part_fee>) that applies to a specific telephone usage class 
(L<FS::usage_class>).  FS::part_fee_usage inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item feepartusagenum - primary key

=item feepart - foreign key to L<FS::part_pkg>

=item classnum - foreign key to L<FS::usage_class>

=item amount - fixed amount to charge per usage record

=item percent - percentage of rated price to charge per usage record

=back

=head1 METHODS

=over 4

=cut

sub table { 'part_fee_usage'; }

sub check {
  my $self = shift;

  $self->set('amount', 0)  unless ($self->amount || 0) > 0;
  $self->set('percent', 0) unless ($self->percent || 0) > 0;

  my $error = 
    $self->ut_numbern('feepartusagenum')
    || $self->ut_foreign_key('feepart', 'part_fee', 'feepart')
    || $self->ut_foreign_key('classnum', 'usage_class', 'classnum')
    || $self->ut_money('amount')
    || $self->ut_float('percent')
  ;
  return $error if $error;

  $self->SUPER::check;
}

# silently discard records with percent = 0 and amount = 0

sub insert {
  my $self = shift;
  if ( $self->amount > 0 or $self->percent > 0 ) {
    return $self->SUPER::insert;
  }
  '';
}

sub replace {
  my ($new, $old) = @_;
  $old ||= $new->replace_old;
  if ( $new->amount > 0 or $new->percent > 0 ) {
    return $new->SUPER::replace($old);
  } elsif ( $old->feepartusagenum ) {
    return $old->delete;
  }
  '';
}
  
=item explanation

Returns a string describing how this fee is calculated.

=cut

sub explanation {
  my $self = shift;
  my $string = '';
  my $money = (FS::Conf->new->config('money_char') || '$') . '%.2f';
  my $percent = '%.1f%%';
  if ( $self->amount > 0 ) {
    $string = sprintf($money, $self->amount);
  }
  if ( $self->percent > 0 ) {
    if ( $string ) {
      $string .= ' plus ';
    }
    $string .= sprintf($percent, $self->percent);
    $string .= ' of the rated charge';
  }
  $string .= ' per '.  $self->usage_class->classname . ' call';

  return $string;
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

