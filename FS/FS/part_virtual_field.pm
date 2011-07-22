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

An FS::part_virtual_field object represents the definition of a custom field 
(see the BACKGROUND section).  FS::part_virtual_field contains the name and 
base table of the field. 

FS::part_virtual_field inherits from FS::Record.  The following fields are 
currently supported:

=over 2

=item vfieldpart - primary key (assigned automatically)

=item name - name of the field

=item dbtable - table for which this virtual field is defined

=item length - expected length of the value (UI hint)

=item label - descriptive label for the field (UI hint)

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'part_virtual_field'; }
sub virtual_fields { () }

=item widget UI_TYPE MODE [ VALUE ]

Generates UI code for a widget suitable for editing/viewing the field, based on 
list_source and length.  

The only UI_TYPE currently supported is 'HTML', and possible MODEs are 'view'
and 'edit'.

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
        $text .= q!<INPUT NAME="! . $self->name .
                q!" VALUE="! . escapeHTML($value) . q!"!;
        if ($self->length) {
          $text .= q! SIZE="! . $self->length . q!"!;
        }
        $text .= '>';
      $text .= q!</TD></TR>! . "\n";
    } else {
      return '';
    }
  } else {
    return '';
  }
  return $text;
}


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

  $self->SUPER::check;  
}

=head1 NOTES

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;


