package FS::export_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_export;
use FS::part_svc;

@ISA = qw(FS::Record);

=head1 NAME

FS::export_svc - Object methods for export_svc records

=head1 SYNOPSIS

  use FS::export_svc;

  $record = new FS::export_svc \%hash;
  $record = new FS::export_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_svc object links a service definition (see L<FS::part_svc>) to
an export (see L<FS::part_export>).  FS::export_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item exportsvcnum - primary key

=item exportnum - export (see L<FS::part_export>)

=item svcpart - service definition (see L<FS::part_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'export_svc'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  return $error if $error;

  #check for duplicates!

  my $label = '';
  my $method = '';
  my $svcdb = $self->part_svc->svcdb;
  if ( $svcdb eq 'svc_acct' ) { #XXX AND UID!  sheesh @method or %method not $method
    if ( $self->part_export->nodomain =~ /^Y/i ) {
      $label = 'usernames';
      $method = 'username';
    } else {
      $label = 'username@domain';
      $method = 'email';
    }
  } elsif ( $svcdb eq 'domain' ) {
    $label = 'domains';
    $method = 'domain';
  } else {
    warn "WARNING: XXX fill in this warning";
  }

  if ( $method ) {
    my @current_svc = $self->part_export->svc_x;
    my @new_svc = $self->part_svc->svc_x;
    my %cur_svc = map { $_->$method() => 1 } @current_svc;
    my @dup_svc = grep { $cur_svc{$_->method()} } @new_svc;

    if ( @dup_svc ) { #aye, that's the rub
      #error out for now, eventually accept different options of adjustments
      # to make to allow us to continue forward
      $dbh->rollback if $oldAutoCommit;
      return "Can't export ".
             $self->part_svc->svcpart.':'.$self->part_svc->svc. " service to ".
             $self->part_export->exportnum.':'.$self->exporttype.
               ' on '. $self->machine.
             " : Duplicate $label: ".
               join(', ', sort map { $_->method() } @dup_svc );
             #XXX eventually a sort sub so usernames and domains are default alpha, username@domain is domain first then username, and uid is numeric
    }
  }

  #end of duplicate check, whew

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

#  if ( $self->part_svc->svcdb eq 'svc_acct' ) {
#
#    if ( $self->part_export->nodomain =~ /^Y/i ) {
#
#      select username from svc_acct where svcpart = $svcpart
#        group by username having count(*) > 1;
#
#    } else {
#
#      select username, domain
#        from   svc_acct
#          join svc_domain on ( svc_acct.domsvc = svc_domain.svcnum )
#        group by username, domain having count(*) > 1;
#
#    }
#
#  } elsif ( $self->part_svc->svcdb eq 'svc_domain' ) {
#
#    #similar but easier domain checking one
#
#  } #etc.?
#
#  my @services =
#    map  { $_->part_svc }
#    grep { $_->svcpart != $self->svcpart }
#         $self->part_export->export_svc;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('exportsvcnum')
    || $self->ut_number('exportnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_number('svcpart')
    || $self->ut_foreign_key('svcpart', 'part_svc', 'svcpart')
    || $self->SUPER::check
  ;
}

=item part_export

Returns the FS::part_export object (see L<FS::part_export>).

=cut

sub part_export {
  my $self = shift;
  qsearchs( 'part_export', { 'exportnum' => $self->exportnum } );
}

=item part_svc

Returns the FS::part_svc object (see L<FS::part_svc>).

=cut

sub part_svc {
  my $self = shift;
  qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::part_svc>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

