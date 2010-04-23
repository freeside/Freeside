package FS::cgp_rule_action;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cgp_rule;

=head1 NAME

FS::cgp_rule_action - Object methods for cgp_rule_action records

=head1 SYNOPSIS

  use FS::cgp_rule_action;

  $record = new FS::cgp_rule_action \%hash;
  $record = new FS::cgp_rule_action { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cgp_rule_action object represents a mail filtering action.
FS::cgp_rule_action inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item ruleactionnum

primary key

=item action

action

=item params

params

=item rulenum

rulenum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new action.  To add the action to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cgp_rule_action'; }

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

Checks all fields to make sure this is a valid action.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('ruleactionnum')
    || $self->ut_text('action')
    || $self->ut_text('params')
    || $self->ut_foreign_key('rulenum', 'cgp_rule', 'rulenum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

