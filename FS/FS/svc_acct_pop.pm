package FS::svc_acct_pop;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );

@ISA = qw( FS::Record );

=head1 NAME

FS::svc_acct_pop - Object methods for svc_acct_pop records

=head1 SYNOPSIS

  use FS::svc_acct_pop;

  $record = new FS::svc_acct_pop \%hash;
  $record = new FS::svc_acct_pop { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_acct object represents an point of presence.  FS::svc_acct_pop
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item popnum - primary key (assigned automatically for new accounts)

=item city

=item state

=item ac - area code

=item exch - exchange

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new point of presence (if only it were that easy!).  To add the 
point of presence to the database, see L<"insert">.

=cut

sub table { 'svc_acct_pop'; }

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

    $self->ut_numbern('popnum')
      or $self->ut_text('city')
      or $self->ut_text('state')
      or $self->ut_number('ac')
      or $self->ut_number('exch')
  ;

}

=back

=head1 VERSION

$Id: svc_acct_pop.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

It should be renamed to part_pop.

=head1 SEE ALSO

L<FS::Record>, L<svc_acct>, schema.html from the base documentation.

=cut

1;

