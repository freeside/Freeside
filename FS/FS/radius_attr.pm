package FS::radius_attr;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use vars qw( $noexport_hack );

=head1 NAME

FS::radius_attr - Object methods for radius_attr records

=head1 SYNOPSIS

  use FS::radius_attr;

  $record = new FS::radius_attr \%hash;
  $record = new FS::radius_attr { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::radius_attr object represents a RADIUS group attribute.
FS::radius_attr inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item attrnum - primary key

=item groupnum - L<FS::radius_group> to assign this attribute

=item attrname - Attribute name, as defined in the RADIUS server's dictionary

=item value - Attribute value

=item attrtype - 'C' (check) or 'R' (reply)

=item op - Operator (see L<http://wiki.freeradius.org/Operators>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'radius_attr'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.  If any sqlradius-type exports exist and have the 
C<export_attrs> option enabled, the new attribute will be exported to them.

=cut

sub insert {
  my $self = shift;
  my $error = $self->SUPER::insert;
  return $error if $error;
  return if $noexport_hack;

  foreach ( qsearch('part_export', {}) ) {
    next if !$_->option('export_attrs',1);
    $error = $_->export_attr_insert($self);
    return $error if $error;
  }

  '';
}


=item delete

Delete this record from the database.  Like C<insert>, this will delete 
the attribute from any attached RADIUS databases.

=cut

sub delete {
  my $self = shift;
  my $error;
  if ( !$noexport_hack ) {
    foreach ( qsearch('part_export', {}) ) {
      next if !$_->option('export_attrs',1);
      $error = $_->export_attr_delete($self);
      return $error if $error;
    }
  }
  
  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ($self, $old) = @_;
  $old ||= $self->replace_old;
  return 'can\'t change radius_attr.groupnum'
    if $self->groupnum != $old->groupnum;
  return ''
    unless grep { $self->$_ ne $old->$_ } qw(attrname value op attrtype);

  # don't attempt export on an invalid record
  my $error = $self->check;
  return $error if $error;

  # exportage
  $old->set('groupname', $old->radius_group->groupname);
  if ( !$noexport_hack ) {
    foreach ( qsearch('part_export', {}) ) {
      next if !$_->option('export_attrs',1);
      $error = $_->export_attr_replace($self, $old);
      return $error if $error;
    }
  }
  
  $self->SUPER::replace($old);
}


=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('attrnum')
    || $self->ut_foreign_key('groupnum', 'radius_group', 'groupnum')
    || $self->ut_text('attrname')
    || $self->ut_text('value')
    || $self->ut_enum('attrtype', [ 'C', 'R' ])
  ;
  return $error if $error;

  my @ops = $self->ops($self->get('attrtype'));
  $self->set('op' => $ops[0]) if !$self->get('op');
  $error ||= $self->ut_enum('op', \@ops);
  
  return $error if $error;

  $self->SUPER::check;
}

=item radius_group

Returns the L<FS::radius_group> object to which this attribute applies.

=cut

sub radius_group {
  my $self = shift;
  qsearchs('radius_group', { 'groupnum' => $self->groupnum });
}

=back

=head1 CLASS METHODS

=over 4

=item ops ATTRTYPE

Returns a list of all legal values of the "op" field.  ATTRTYPE must be C for 
check or R for reply.

=cut

my %ops = (
  C => [ '==', ':=', '+=', '!=', '>', '>=', '<', '<=', '=~', '!~', '=*', '!*' ],
  R => [ '=', ':=', '+=' ],
);

sub ops {
  my $self = shift;
  my $attrtype = shift;
  return @{ $ops{$attrtype} };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;
