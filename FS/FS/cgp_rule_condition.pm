package FS::cgp_rule_condition;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cgp_rule;

=head1 NAME

FS::cgp_rule_condition - Object methods for cgp_rule_condition records

=head1 SYNOPSIS

  use FS::cgp_rule_condition;

  $record = new FS::cgp_rule_condition \%hash;
  $record = new FS::cgp_rule_condition { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cgp_rule_condition object represents a mail filtering condition.
FS::cgp_rule_condition inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item ruleconditionnum

primary key

=item condition

condition

=item op

op

=item params

params

=item rulenum

rulenum

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new condition.  To add the condition to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cgp_rule_condition'; }

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

Checks all fields to make sure this is a valid condition.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('ruleconditionnum')
    || $self->ut_text('condition')
    || $self->ut_textn('op')
    || $self->ut_textn('params')
    || $self->ut_foreign_key('rulenum', 'cgp_rule', 'rulenum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item arrayref

Returns an array reference of the condition, op and params fields.

=cut

sub arrayref {
  my $self = shift;
  [ map $self->$_, qw( condition op params ) ];
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

