package FS::part_export;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_svc;
use FS::part_export_option;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  ($new_record, $options) = $template_recored->clone( $svcpart );

  $error = $record->insert( { 'option' => 'value' } );
  $error = $record->insert( \$options );

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export object represents an export of Freeside data to an external
provisioning system.  FS::part_export inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item exportnum - primary key

=item svcpart - Service definition (see L<FS::part_svc>) to which this export applies

=item machine - Machine name 

=item exporttype - Export type

=item nodomain - blank or "Y" : usernames are exported to this service with no domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export.  To add the export to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export'; }

=item clone SVCPART

An alternate constructor.  Creates a new export by duplicating an existing
export.  The given svcpart is assigned to the new export.

Returns a list consisting of the new export object and a hashref of options.

=cut

sub clone {
  my $self = shift;
  my $class = ref($self);
  my %hash = $self->hash;
  $hash{'exportnum'} = '';
  $hash{'svcpart'} = shift;
  ( $class->new( \%hash ),
    { map { $_->optionname => $_->optionvalue }
        qsearch('part_export_option', { 'exportnum' => $self->exportnum } )
    }
  );
}

=item insert HASHREF

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created (see L<FS::part_export_option>).

=cut

#false laziness w/queue.pm
sub insert {
  my $self = shift;
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $options = shift;
  foreach my $optionname ( keys %{$options} ) {
    my $part_export_option = new FS::part_export_option ( {
      'optionname'  => $optionname,
      'optionvalue' => $options->{$optionname},
    } );
    $error = $part_export_option->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

};

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

Checks all fields to make sure this is a valid export.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error = 
    $self->ut_numbern('exportnum')
    || $self->ut_number('svcpart')
    || $self->ut_alpha('exporttype')
  ;
  return $error if $error;

  return "Unknown svcpart: ". $self->svcpart
    unless qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );

  $self->machine =~ /^([\w\-\.]*)$/
    or return "Illegal machine: ". $self->machine;
  $self->machine($1);

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  #check exporttype?

  ''; #no error
}

=item part_svc

Returns the service definition (see L<FS::part_svc>) for this export.

=cut

sub part_svc {
  my $self = shift;
  qsearchs('part_svc', { svcpart => $self->svcpart } );
}

=back

=head1 BUGS

Probably.

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::part_svc>, L<FS::svc_acct>, L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

