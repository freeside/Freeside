package FS::part_sb_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );

@ISA = qw( FS::Record );

=head1 NAME

FS::part_sb_field - Object methods for part_sb_field records

=head1 SYNOPSIS

  use FS::part_sb_field;

  $record = new FS::part_sb_field \%hash;
  $record = new FS::part_sb_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_sb_field object represents an extended field (xfield) definition 
for svc_broadband's sb_field mechanism (see L<FS::svc_broadband>).  
FS::part_sb_field inherits from FS::Record.  The following fields are 
currently supported:

=over 2

=item sbfieldpart - primary key (assigned automatically)

=item name - name of the field

=item svcpart - service type for which this field is available (see L<FS::part_svc>)

=item length - length of the contents of the field (see note #1)

=item check_block - validation routine (see note #2)

=item list_source - enumeration routine (see note #3)

=back

=head1 BACKGROUND

Broadband services, unlike dialup services, are provided over a wide 
variety of physical media (DSL, wireless, cable modems, digital circuits) 
and network architectures (Ethernet, PPP, ATM).  For many of these access 
mechanisms, adding a new customer requires knowledge of some properties 
of the physical connection (circuit number, the type of CPE in use, etc.).
It is unreasonable to expect ISPs to alter Freeside's schema (and the 
associated library and UI code) to make each of these parameters a field in 
svc_broadband.

Hence sb_field and part_sb_field.  They allow the Freeside administrator to
define 'extended fields' ('xfields') associated with svc_broadband records.
These are I<not> processed in any way by Freeside itself; they exist solely for
use by exports (see L<FS::part_export>) and technical support staff.

For a parallel mechanism (at the per-router level rather than per-service), 
see L<FS::part_router_field>.

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'part_sb_field'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;
  my $error = '';

  $error = $self->ut_numbern('svcpart');
  return $error if $error;

  unless (qsearchs('part_svc', { svcpart => $self->svcpart }))
    { return "Unknown svcpart: " . $self->svcpart;}

  $self->name =~ /^([a-z0-9_\-\.]{1,15})$/i
    or return "Invalid field name for part_sb_field";

  #How to check input_block, display_block, and check_block?

  ''; #no error
}

=item list_values

If the I<list_source> field is set, this method eval()s it and 
returns its output.  If the field is empty, list_values returns 
an empty list.

Any arguments passed to this method will be received by the list_source 
code, but this behavior is a fortuitous accident and may be removed in 
the future.

=cut

sub list_values {
  my $self = shift;
  return () unless $self->list_source;

  my @opts = eval($self->list_source);
  if($@) {
    warn $@;
    return ();
  } else {
    return @opts;
  }
}

=item part_svc

Returns the FS::part_svc object associated with this field definition.

=cut

sub part_svc {
  my $self = shift;
  return qsearchs('part_svc', { svcpart => $self->svcpart });
}

=back

=head1 VERSION

$Id: 

=head1 NOTES

=over

=item 1.

The I<length> field is not enforced.  It provides a hint to UI
code about how to display the field on a form.  If you want to enforce a
minimum or maximum length for a field, use a I<check_block>.

=item 2.

The check_block mechanism used here as well as in
FS::part_router_field allows the user to define validation rules.

When FS::sb_field::check is called, the proposed value of the xfield is
assigned to $_.  The check_block is then eval()'d and its return value
captured.  If the return value is false (empty/zero/undef), $_ is then assigned
back into the field and stored in the database.

Therefore a check_block can do three different things with the value: allow
it, allow it with a modification, or reject it.  This is very flexible, but
somewhat dangerous.  Some warnings:

=over 2

=item *

Assume that $_ has had I<no> error checking prior to the
check_block.  That's what the check_block is for, after all.  It could
contain I<anything>: evil shell commands in backquotes, 100kb JPEG images,
the Klez virus, whatever.

=item *

If your check_block modifies the input value, it should probably
produce a value that wouldn't be modified by going through the same
check_block again.  (That is, it should map input values into its own
eigenspace.)  The reason is that if someone calls $new->replace($old),
where $new and $old contain the same value for the field, they probably
want the field to keep its old value, not to get transformed by the
check_block again.  So don't do silly things like '$_++' or
'tr/A-Za-z/a-zA-Z/'.

=item *

Don't alter the contents of the database.  I<Reading> the database
is perfectly reasonable, but writing to it is a bad idea.  Remember that
check() might get called more than once, as described above.

=item *

The check_block probably won't even get called if the user submits
an I<empty> sb_field.  So at present, you can't set up a default value with
something like 's/^$/foo/'.  Conversely, don't replace the submitted value
with an empty string.  It probably will get stored, but might be deleted at
any time.

=back

=item 3.

The list_source mechanism is a UI hint (like length) to generate
drop-down or list boxes.  If list_source contains a value, the UI code can
eval() it and use the results as the options on the list.

Note 'can'.  This is not a substitute for check_block.  The HTML interface
currently requires that the user pick one of the options on the list
because that's the way HTML drop-down boxes work, but in the future the UI
code might add an 'Other (please specify)' option and a text box so that
the user can enter something else.  Or it might ignore list_source and just
generate a text box.  Or the interface might be rewritten in MS Access,
where drop-down boxes have text boxes built in.  Data validation is the job
of check(), not the front end.

Note also that a list of literals evaluates to itself, so a list_source
like

C<('Windows', 'MacOS', 'Linux')>

or

C<qw(Windows MacOS Linux)>

means exactly what you'd think.

=head1 BUGS

The lack of any way to do default values.  We might add this as another UI
hint (since, for the most part, it's the UI's job to figure out which fields
have had values entered into them).  In fact, there are lots of things we
should add as UI hints.

Oh, and the documentation is probably full of lies.

=head1 SEE ALSO

FS::svc_broadband, FS::sb_field, schema.html from the base documentation.

=cut

1;

