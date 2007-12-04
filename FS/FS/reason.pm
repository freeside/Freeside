package FS::reason;

use strict;
use vars qw( @ISA $DEBUG $me );
use DBIx::DBSchema;
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::reason_type;

@ISA = qw(FS::Record);
$DEBUG = 0;
$me = '[FS::reason]';

=head1 NAME

FS::reason - Object methods for reason records

=head1 SYNOPSIS

  use FS::reason;

  $record = new FS::reason \%hash;
  $record = new FS::reason { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::reason object represents a reason message.  FS::reason inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item reasonnum - primary key

=item reason_type - index into FS::reason_type

=item reason - text of the reason

=item disabled - 'Y' or ''


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new reason.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'reason'; }

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

Checks all fields to make sure this is a valid reason.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('reasonnum')
    || $self->ut_text('reason')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item reasontype

Returns the reason_type (see <I>FS::reason_type</I>) associated with this reason.

=cut

sub reasontype {
  qsearchs( 'reason_type', { 'typenum' => shift->reason_type } );
}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {  # class method
  my ($self, %opts) = @_;
  my $dbh = dbh;

  warn "$me upgrading $self\n" if $DEBUG;

  my $column = dbdef->table($self->table)->column('reason');
  unless ($column->type eq 'text') { # assume history matches main table

    # ideally this would be supported in DBIx-DBSchema and friends
    warn "$me Shifting reason column to type 'text'\n" if $DEBUG;
    foreach my $table ( $self->table, 'h_'. $self->table ) {
      my @sql = ();

      $column = dbdef->table($self->table)->column('reason');
      my $columndef = $column->line($dbh);
      $columndef =~ s/varchar\(\d+\)/text/i;
      if ( $dbh->{Driver}->{Name} eq 'Pg' ) {
        my $notnull = $columndef =~ s/not null//i;
        push @sql,"ALTER TABLE $table RENAME reason TO freeside_upgrade_reason";
        push @sql,"ALTER TABLE $table ADD $columndef";
        push @sql,"UPDATE $table SET reason = freeside_upgrade_reason";
        push @sql,"ALTER TABLE $table ALTER reason SET NOT NULL"
          if $notnull;
        push @sql,"ALTER TABLE $table DROP freeside_upgrade_reason";
      }elsif( $dbh->{Driver}->{Name} =~ /^mysql/i ){
        push @sql,"ALTER TABLE $table MODIFY reason ". $column->line($dbh);
      }else{
        die "watchu talkin' 'bout, Willis? (unsupported database type)";
      }

      foreach (@sql) {
        my $sth = $dbh->prepare($_) or die $dbh->errstr;
        $sth->execute or die $dbh->errstr;
      }
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

