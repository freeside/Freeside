package FS::access_user_page_pref;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

sub table { 'access_user_page_pref'; }

=head1 NAME

FS::access_user_page_pref - Object methods for access_user_page_pref records

=head1 SYNOPSIS

  use FS::access_user_page_pref;

  $record = new FS::access_user_page_pref \%hash;
  $record = new FS::access_user_page_pref { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_user_page_pref object represents a per-page user interface
preference.  FS::access_user_page_pref inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item prefnum

primary key

=item usernum

The user who has this preference, a L<FS::access_user> foreign key.

=item path

The path of the page where the preference is set, relative to the Mason
document root.

=item tablenum

For view and edit pages (which show one record at a time), the record primary
key that the preference applies to.

=item _date

The date the preference was created.

=item prefname

The name of the preference, as defined by the page.

=item prefvalue

The value (a free-text field).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new preference.  To add the preference to the database, see
L<"insert">.

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid preference.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->set('_date', time) unless $self->get('_date');

  my $error = 
    $self->ut_numbern('prefnum')
    || $self->ut_number('usernum')
    || $self->ut_foreign_key('usernum', 'access_user', 'usernum')
    || $self->ut_text('path')
    || $self->ut_numbern('tablenum')
    || $self->ut_numbern('_date')
    || $self->ut_text('prefname')
    || $self->ut_text('prefvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

