package FS::cust_tag;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearchs );
use FS::cust_main;
use FS::part_tag;

=head1 NAME

FS::cust_tag - Object methods for cust_tag records

=head1 SYNOPSIS

  use FS::cust_tag;

  $record = new FS::cust_tag \%hash;
  $record = new FS::cust_tag { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_tag object represents a customer tag.  FS::cust_tag inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item custtagnum

primary key

=item custnum

custnum

=item tagnum

tagnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer tag.  To add the tag to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_tag'; }

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

Checks all fields to make sure this is a valid customer tag.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('custtagnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_foreign_key('tagnum',  'part_tag',  'tagnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_main

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item part_tag

=cut

sub part_tag {
  my $self = shift;
  qsearchs( 'part_tag', { 'tagnum' => $self->tagnum } );
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

