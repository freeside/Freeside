package FS::part_pop_local;

use strict;
use vars qw( @ISA );
use FS::Record; # qw( qsearchs );

@ISA = qw( FS::Record );

=head1 NAME

FS::part_pop_local - Object methods for part_pop_local records

=head1 SYNOPSIS

  use FS::part_pop_local;

  $record = new FS::part_pop_local \%hash;
  $record = new FS::part_pop_local { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pop_local object represents a local call area.  Each
FS::part_pop_local record maps a NPA/NXX (area code and exchange) to the POP
(see L<FS::svc_acct_pop>) which is a local call.  FS::part_pop_local inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item localnum - primary key (assigned automatically for new accounts)

=item popnum - see L<FS::svc_acct_pop>

=item city

=item state

=item npa - area code

=item nxx - exchange

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new point of presence (if only it were that easy!).  To add the 
point of presence to the database, see L<"insert">.

=cut

sub table { 'part_pop_local'; }

=item insert

Adds this point of presence to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Removes this point of presence from the database.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid point of presence.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

    $self->ut_numbern('localnum')
      or $self->ut_numbern('popnum')
      or $self->ut_text('city')
      or $self->ut_text('state')
      or $self->ut_number('npa')
      or $self->ut_number('nxx')
      or $self->SUPER::check
  ;

}

=back

=head1 BUGS

US/CA-centric.

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_acct_pop>, schema.html from the base documentation.

=cut

1;

