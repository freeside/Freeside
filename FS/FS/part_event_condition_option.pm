package FS::part_event_condition_option;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::option_Common;
use FS::part_event_condition;

@ISA = qw( FS::option_Common ); # FS::Record);

=head1 NAME

FS::part_event_condition_option - Object methods for part_event_condition_option records

=head1 SYNOPSIS

  use FS::part_event_condition_option;

  $record = new FS::part_event_condition_option \%hash;
  $record = new FS::part_event_condition_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_event_condition_option object represents an event condition option.
FS::part_event_condition_option inherits from FS::Record.  The following fields
are currently supported:

=over 4

=item optionnum - primary key

=item eventconditionnum - Event condition (see L<FS::part_event_condition>)

=item optionname - Option name

=item optionvalue - Option value

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_event_condition_option'; }

=item insert [ HASHREF | OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a list or hash reference of options is supplied,
part_event_condition_option_option records are created (see
L<FS::part_event_condition_option_option>).

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list or hash reference of options is supplied,
part_event_condition_option_option records are created or modified (see
L<FS::part_event_condition_option_option>).

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('eventconditionnum',
                               'part_event_condition', 'eventconditionnum')
    || $self->ut_text('optionname')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

#this makes the nested options magically show up as perl refs
#move it to a mixin class if we need nested options again
sub optionvalue {
  my $self = shift;
  if ( scalar(@_) ) { #setting, no magic (here, insert takes care of it)
    $self->set('optionvalue', @_);
  } else { #getting, magic
    my $optionvalue = $self->get('optionvalue');
    if ( $optionvalue eq 'HASH' ) {
      return { $self->options };
    } else {
      $optionvalue;
    }
  }
}

use FS::upgrade_journal;
sub _upgrade_data { #class method
  my ($class, %opts) = @_;

  # migrate part_event_condition_option agentnum to part_event_condition_option_option agentnum
  unless ( FS::upgrade_journal->is_done('agentnum_to_hash') ) {

    foreach my $condition_option (qsearch('part_event_condition_option', { optionname => 'agentnum', })) {
      my $optionvalue = $condition_option->get("optionvalue");
      if ($optionvalue eq 'HASH' ) { next; }
      else {
        my $options = {"$optionvalue" => '1',};
        $condition_option->optionvalue(ref($options));
        my $error = $condition_option->replace($options);
        die $error if $error;
      }
    }

    FS::upgrade_journal->set_done('agentnum_to_hash');

  }

}

=back

=head1 SEE ALSO

L<FS::part_event_condition>, L<FS::part_event_condition_option_option>, 
L<FS::Record>, schema.html from the base documentation.

=cut

1;

