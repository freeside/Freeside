package FS::part_referral;

use strict;
use vars qw( @ISA );
use FS::Record;

@ISA = qw( FS::Record );

=head1 NAME

FS::part_referral - Object methods for part_referral objects

=head1 SYNOPSIS

  use FS::part_referral;

  $record = new FS::part_referral \%hash
  $record = new FS::part_referral { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_referral represents a referral - where a customer heard of your
services.  This can be used to track the effectiveness of a particular piece of
advertising, for example.  FS::part_referral inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item refnum - primary key (assigned automatically for new referrals)

=item referral - Text name of this referral

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new referral.  To add the referral to the database, see L<"insert">.

=cut

sub table { 'part_referral'; }

=item insert

Adds this referral to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Currently unimplemented.

=cut

sub delete {
  my $self = shift;
  return "Can't (yet?) delete part_referral records";
  #need to make sure no customers have this referral!
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid referral.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('refnum')
    || $self->ut_text('referral')
  ;
}

=back

=head1 VERSION

$Id: part_referral.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

The delete method is unimplemented.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, schema.html from the base documentation.

=cut

1;

