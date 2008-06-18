package FS::part_virtual_field;

use strict;
use vars qw( @ISA );
use FS::Record;
use FS::Schema qw( dbdef );
use CGI qw(escapeHTML);

@ISA = qw( FS::Record );

=head1 NAME

FS::part_virtual_field - Object methods for part_virtual_field records

=head1 SYNOPSIS

  use FS::part_virtual_field;

  $record = new FS::part_virtual_field \%hash;
  $record = new FS::part_virtual_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_virtual_field object represents the definition of a virtual field 
(see the BACKGROUND section).  FS::part_virtual_field contains the name and 
base table of the field, as well as validation rules and UI hints about the 
display of the field.  The actual data is stored in FS::virtual_field; see 
its manpage for details.

FS::part_virtual_field inherits from FS::Record.  The following fields are 
currently supported:

=over 2

=item vfieldpart - primary key (assigned automatically)

=item name - name of the field

=item dbtable - table for which this virtual field is defined

=item check_block - Perl code to validate/normalize data

=item list_source - Perl code to generate a list of values (UI hint)

=item length - expected length of the value (UI hint)

=item label - descriptive label for the field (UI hint)

=item sequence - sort key (UI hint; unimplemented)

=back

=head1 BACKGROUND

"Form is none other than emptiness,
 and emptiness is none other than form."
-- Heart Sutra

The virtual field mechanism allows site admins to make trivial changes to 
the Freeside database schema without modifying the code.  Specifically, the 
user can add custom-defined 'fields' to the set of data tracked by Freeside 
about objects such as customers and services.  These fields are not associated 
with any logic in the core Freeside system, but may be referenced in peripheral 
code such as exports, price calculations, or alternate interfaces, or may just 
be stored in the database for future reference.

This system was originally devised for svc_broadband, which (by necessity) 
comprises such a wide range of access technologies that no static set of fields 
could contain all the information needed by the exports.  In an appalling 
display of False Laziness, a parallel mechanism was implemented for the 
router table, to store properties such as passwords to configure routers.

The original system treated svc_broadband custom fields (sb_fields) as records 
in a completely separate table.  Any code that accessed or manipulated these 
fields had to be aware that they were I<not> fields in svc_broadband, but 
records in sb_field.  For example, code that inserted a svc_broadband with 
several custom fields had to create an FS::svc_broadband object, call its 
insert() method, and then create several FS::sb_field objects and call I<their>
insert() methods.

This created a problem for exports.  The insert method on any FS::svc_Common 
object (including svc_broadband) automatically triggers exports after the 
record has been inserted.  However, at this point, the sb_fields had not yet 
been inserted, so the export could not rely on their presence, which was the 
original purpose of sb_fields.

Hence the new system.  Virtual fields are appended to the field list of every 
record at the FS::Record level, whether the object is created ex nihilo with 
new() or fetched with qsearch().  The fields() method now returns a list of 
both real and virtual fields.  The insert(), replace(), and delete() methods 
now update both the base table and the virtual fields, in a single transaction.

A new method is provided, virtual_fields(), which gives only the virtual 
fields.  UI code that dynamically generates form widgets to edit virtual field
data should use this to figure out what fields are defined.  (See below.)

Subclasses may override virtual_fields() to restrict the set of virtual 
fields available.  Some discipline and sanity on the part of the programmer 
are required; in particular, this function should probably not depend on any 
fields in the record other than the primary key, since the others may change 
after the object is instantiated.  (Making it depend on I<virtual> fields is 
just asking for pain.)  One use of this is seen in FS::svc_Common; another 
possibility is field-level access control based on FS::UID::getotaker().

As a trivial case, a subclass may opt out of supporting virtual fields with 
the following code:

sub virtual_fields { () }

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'part_virtual_field'; }
sub virtual_fields { () }

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

If there is an error, returns the error, otherwise returns false.
Called by the insert and replace methods.

=back

=cut

sub check {
  my $self = shift;

  my $error = $self->ut_text('name') ||
              $self->ut_text('dbtable') ||
              $self->ut_number('length')
              ;
  return $error if $error;

  # Make sure it's a real table with a numeric primary key
  my ($table, $pkey);
  if($table = dbdef->table($self->dbtable)) {
    if($pkey = $table->primary_key) {
      if($table->column($pkey)->type =~ /int/i) {
        # this is what it should be
      } else {
        $error = "$table.$pkey is not an integer";
      }
    } else {
      $error = "$table does not have a single-field primary key";
    }
  } else {
    $error = "$table does not exist in the schema";
  }
  return $error if $error;

  # Possibly some sanity checks for check_block and list_source?

  $self->SUPER::check;  
}

=item list

Evaluates list_source.

=cut

sub list {
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

=item widget UI_TYPE MODE [ VALUE ]

Generates UI code for a widget suitable for editing/viewing the field, based on 
list_source and length.  

The only UI_TYPE currently supported is 'HTML', and the only MODE is 'view'.
Others will be added later.

In HTML, all widgets are assumed to be table rows.  View widgets look like
<TR><TD ALIGN="right">Label</TD><TD BGCOLOR="#ffffff">Value</TD></TR>

(Most of the display style stuff, such as the colors, should probably go into 
a separate module specific to the UI.  That can wait, though.  The API for 
this function won't change.)

VALUE (optional) is the current value of the field.

=cut

sub widget {
  my $self = shift;
  my ($ui_type, $mode, $value) = @_;
  my $text;
  my $label = $self->label || $self->name;

  if ($ui_type eq 'HTML') {
    if ($mode eq 'view') {
      $text = q!<TR><TD ALIGN="right">! . $label . 
              q!</TD><TD BGCOLOR="#ffffff">! . $value .
              q!</TD></TR>! . "\n";
    } elsif ($mode eq 'edit') {
      $text = q!<TR><TD ALIGN="right">! . $label .
              q!</TD><TD>!;
      if ($self->list_source) {
        $text .= q!<SELECT NAME="! . $self->name . 
                q!" SIZE=1>! . "\n";
        foreach ($self->list) {
          $text .= q!<OPTION VALUE="! . $_ . q!"!;
          $text .= ' SELECTED' if ($_ eq $value);
          $text .= '>' . $_ . '</OPTION>' . "\n";
        }
      } else {
        $text .= q!<INPUT NAME="! . $self->name .
                q!" VALUE="! . escapeHTML($value) . q!"!;
        if ($self->length) {
          $text .= q! SIZE="! . $self->length . q!"!;
        }
        $text .= '>';
      }
      $text .= q!</TD></TR>! . "\n";
    } else {
      return '';
    }
  } else {
    return '';
  }
  return $text;
}

=head1 NOTES

=head2 Semantics of check_block:

This has been changed from the sb_field implementation to make check_blocks 
simpler and more natural to Perl programmers who work on things other than 
Freeside.

The check_block is eval'd with the (proposed) new value of the field in $_, 
and the object to be updated in $self.  Its return value is ignored.  The 
check_block may change the value of $_ to override the proposed value, or 
call die() (with an appropriate error message) to reject the update entirely;
the error string will be returned as the output of the check() method.

This makes check_blocks like

C<s/foo/bar/>

do what you expect.

The check_block is expected NOT to do anything freaky to $self, like modifying 
other fields or calling $self->check().  You have been warned.

(FIXME: Rewrite some of the warnings from part_sb_field and insert here.)

=head1 BUGS

None.  It's absolutely falwless.

=head1 SEE ALSO

L<FS::Record>, L<FS::virtual_field>

=cut

1;


