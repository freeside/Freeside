package FS::svc_acct_rt_transaction;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw(FS::Record);

=head1 NAME

FS::svc_acct_rt_transaction - Object methods for svc_acct_rt_transaction records

=head1 SYNOPSIS

  use FS::svc_acct_rt_transaction;

  $record = new FS::svc_acct_rt_transaction \%hash;
  $record = new FS::svc_acct_rt_transaction { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_acct_rt_transaction object represents an application of time
from a rt transaction to a svc_acct.  FS::svc_acct_rt_transaction inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item svcrtid - primary key

=item svcnum -  the svcnum of the svc_acct to which the time applies

=item transaction_id -  the id of the rt transtaction from which the time applies

=item seconds - the amount of time which applies


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_acct_rt_transaction.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_acct_rt_transaction'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my( $self, %options ) = @_;
  
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert($options{options} ? %{$options{options}} : ());
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $svc_acct = qsearchs('svc_acct', {'svcnum' => $self->svcnum});
  unless ($svc_acct) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't find svc_acct " . $self->svcnum;
  }

  my $error = $svc_acct->decrement_seconds($self->seconds);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error incrementing service seconds: $error";
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}


=item delete

Delete this record from the database.

=cut

sub delete { 
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

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $svc_acct = qsearchs('svc_acct', {'svcnum' => $self->svcnum});
  unless ($svc_acct) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't find svc_acct " . $self->svcnum;
  }

  my $error = $svc_acct->increment_seconds($self->seconds);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "Error incrementing service seconds: $error";
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid svc_acct_rt_transaction.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my ($selfref) = $self->hashref;

  my $error = 
    $self->ut_numbern('svcrtid')
    || $self->ut_numbern('svcnum')
    || $self->ut_number('transaction_id')
    || $self->ut_numbern('_date')
    || $self->ut_snumber('seconds')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  if ($selfref->{custnum}) {
    my $conf = new FS::Conf;
    my %packages = map { $_ => 1 } $conf->config('support_packages');
    my $cust_main = qsearchs('cust_main',{ 'custnum' => $selfref->{custnum} } );
    return "Invalid custnum: " . $selfref->{custnum} unless $cust_main;

    my (@svcs) = map { $_->svcnum } $cust_main->support_services;
    return "svcnum ". $self->svcnum. " invalid for custnum ".$selfref->{custnum}
      unless (!$self->svcnum || scalar(grep { $_ == $self->svcnum } @svcs));

    $self->svcnum($svcs[0]) unless $self->svcnum;
    return "Can't find support service for custnum ".$selfref->{custnum}
      unless $self->svcnum;
  }

  $self->SUPER::check;
}

=item batch_insert SVC_ACCT_RT_TRANSACTION_OBJECT, ...

Class method which inserts multiple time applications.  Takes a list of
FS::svc_acct_rt_transaction objects.  If there is an error inserting any
application, the entire transaction is rolled back, i.e. all time is applied
or none is.

For example:

  my $errors = FS::svc_acct_rt_transaction->batch_insert(@transactions);
  if ( $error ) {
    #success; all payments were inserted
  } else {
    #failure; no payments were inserted.
  }

=cut

sub batch_insert {
  my $self = shift; #class method

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error;
  foreach (@_) {
    $error = $_->insert;
    last if $error;
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
  } else {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  }

  $error;

}

=back

=head1 BUGS

Possibly the delete method or others.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

