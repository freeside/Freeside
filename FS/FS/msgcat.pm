package FS::msgcat;

use strict;
use vars qw( @ISA );
use Exporter;
use FS::UID;
use FS::Record qw( qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::msgcat - Object methods for message catalog entries

=head1 SYNOPSIS

  use FS::msgcat;

  $record = new FS::msgcat \%hash;
  $record = new FS::msgcat { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::msgcat object represents an message catalog entry.  FS::msgcat inherits 
from FS::Record.  The following fields are currently supported:

=over 4

=item msgnum - primary key

=item msgcode - Error code

=item locale - Locale

=item msg - Message

=back

If you just want to B<use> message catalogs, see L<FS::Msgcat>.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new message catalog entry.  To add the message catalog entry to the
database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'msgcat'; }

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

Checks all fields to make sure this is a valid message catalog entry.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('msgnum')
    || $self->ut_text('msgcode')
    || $self->ut_text('msg')
  ;
  return $error if $error;

  $self->locale =~ /^([\w\@]+)$/ or return "illegal locale: ". $self->locale;
  $self->locale($1);

  $self->SUPER::check
}


sub _upgrade_data { #class method
  my( $class, %opts) = @_;

  eval "use FS::Setup;";
  die $@ if $@;

  #"repopulate_msgcat", false laziness w/FS::Setup::populate_msgcat

  my %messages = FS::Setup::msgcat_messages();

  foreach my $msgcode ( keys %messages ) {
    foreach my $locale ( keys %{$messages{$msgcode}} ) {
      my %msgcat = (
        'msgcode' => $msgcode,
        'locale'  => $locale,
        #'msg'     => $messages{$msgcode}{$locale},
      );
      #my $msgcat = qsearchs('msgcat', \%msgcat);
      my $msgcat = FS::Record::qsearchs('msgcat', \%msgcat); #wtf?
      next if $msgcat;

      $msgcat = new FS::msgcat( {
        %msgcat,
        'msg' => $messages{$msgcode}{$locale},
      } );
      my $error = $msgcat->insert;
      die $error if $error;
    }
  }

}

=back

=head1 BUGS

i18n/l10n, eek

=head1 SEE ALSO

L<FS::Msgcat>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

