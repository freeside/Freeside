package FS::nas;

use strict;
use vars qw( @ISA );
use FS::Record qw(qsearchs); #qsearch);
use FS::UID qw( dbh );

@ISA = qw(FS::Record);

=head1 NAME

FS::nas - Object methods for nas records

=head1 SYNOPSIS

  use FS::nas;

  $record = new FS::nas \%hash;
  $record = new FS::nas {
    'nasnum'  => 1,
    'nasip'   => '10.4.20.23',
    'nasfqdn' => 'box1.brc.nv.us.example.net',
  };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->heartbeat($timestamp);

=head1 DESCRIPTION

An FS::nas object represents an Network Access Server on your network, such as
a terminal server or equivalent.  FS::nas inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item nasnum - primary key

=item nas - NAS name

=item nasip - NAS ip address

=item nasfqdn - NAS fully-qualified domain name

=item last - timestamp indicating the last instant the NAS was in a known
             state (used by the session monitoring).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new NAS.  To add the NAS to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'nas'; }

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

Checks all fields to make sure this is a valid NAS.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('nasnum')
    || $self->ut_text('nas')
    || $self->ut_ip('nasip')
    || $self->ut_domain('nasfqdn')
    || $self->ut_numbern('last')
    || $self->SUPER::check
    ;
}

=item heartbeat TIMESTAMP

Updates the timestamp for this nas

=cut

sub heartbeat {
  my($self, $timestamp) = @_;
  my $dbh = dbh;
  my $sth =
    $dbh->prepare("UPDATE nas SET last = ? WHERE nasnum = ? AND last < ?");
  $sth->execute($timestamp, $self->nasnum, $timestamp) or die $sth->errstr;
  $self->last($timestamp);
}

=back

=head1 BUGS

heartbeat method uses SQL directly and doesn't update history tables.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

