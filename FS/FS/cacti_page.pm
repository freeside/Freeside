package FS::cacti_page;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cacti_page - Object methods for cacti_page records

=head1 SYNOPSIS

  use FS::cacti_page;

  $record = new FS::cacti_page \%hash;
  $record = new FS::table_name {
              'exportnum' => 3,           #part_export associated with this page
              'svcnum'   => 123,          #svc_broadband associated with this page
              'graphnum' => 45,           #blank for svcnum index
              'imported' => 1428358699,   #date of import
              'content'  => $htmlcontent, #html containing base64-encoded images
  };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cacti_page object represents an html page for viewing cacti graphs.
FS::cacti_page inherits from FS::Record.  The following fields are currently supported:

=over 4

=item cacti_pagenum - primary key

=item exportnum - part_export exportnum for this page

=item svcnum - svc_broadband svcnum for this page

=item graphnum - cacti graphnum for this page (blank for overview page)

=item imported - date this page was imported

=item content - text/html content of page, should not include newlines

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new object.  To add the object to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cacti_page'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('cacti_pagenum', 'graphnum')
    || $self->ut_foreign_key('exportnum','part_export','exportnum')
    || $self->ut_foreign_key('svcnum','cust_svc','svcnum')
    || $self->ut_number('imported')
    || $self->ut_text('content')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Will be described here once found.

=head1 SEE ALSO

L<FS::Record>

=cut

1;

