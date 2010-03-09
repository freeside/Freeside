package FS::reason_type;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

our %class_name = (  
  'C' => 'cancel',
  'R' => 'credit',
  'S' => 'suspend',
);

our %class_purpose = (  
  'C' => 'explain why a customer package was cancelled',
  'R' => 'explain why a customer was credited',
  'S' => 'explain why a customer package was suspended',
);

=head1 NAME

FS::reason_type - Object methods for reason_type records

=head1 SYNOPSIS

  use FS::reason_type;

  $record = new FS::reason_type \%hash;
  $record = new FS::reason_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::reason_type object represents a grouping of reasons.  FS::reason_type
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item typenum - primary key

=item class - currently 'C', 'R',  or 'S' for cancel, credit, or suspend 

=item type - name of the type of reason


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new reason_type.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'reason_type'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid reason_type.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('typenum')
    || $self->ut_enum('class', [ keys %class_name ] )
    || $self->ut_text('type')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item reasons

Returns a list of all reasons associated with this type.

=cut

sub reasons {
  qsearch( 'reason', { 'reason_type' => shift->typenum } );
}

=item enabled_reasons

Returns a list of enabled reasons associated with this type.

=cut

sub enabled_reasons {
  qsearch( 'reason', { 'reason_type' => shift->typenum,
                       'enabled'     => '',
		     } );
}

# _populate_initial_data
#
# Used by FS::Setup to initialize a new database.
#
#

sub _populate_initial_data {  # class method
  my ($self, %opts) = @_;

  my $conf = new FS::Conf;

  foreach ( keys %class_name ) {
    my $object  = $self->new( {'class' => $_,
                               'type' => ucfirst($class_name{$_}). ' Reason',
                            } );
    my $error   = $object->insert();
    die "error inserting $self into database: $error\n"
      if $error;
  }

  my $object = qsearchs('reason_type', { 'class' => 'R' });
  die "can't find credit reason type just inserted!\n"
    unless $object;

  foreach ( keys %FS::cust_credit::reasontype_map ) {
#   my $object  = $self->new( {'class' => 'R',
#                              'type' => $FS::cust_credit::reasontype_map{$_},
#                           } );
#   my $error   = $object->insert();
#   die "error inserting $self into database: $error\n"
#     if $error;
    $conf->set($_, $object->typenum);
  }

  '';

}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {  # class method
  my ($self, %opts) = @_;

  foreach ( keys %class_name ) {
    unless (scalar(qsearch('reason_type', { 'class' => $_ }))) {
      my $object  = $self->new( {'class' => $_,
                                 'type' => ucfirst($class_name{$_}),
                              } );
      my $error   = $object->insert();
      die "error inserting $self into database: $error\n"
        if $error;
    }
  }

  '';

}

=back

=head1 BUGS

Here be termintes.  Don't use on wooden computers.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

