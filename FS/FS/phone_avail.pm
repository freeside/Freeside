package FS::phone_avail;

use strict;
use vars qw( @ISA $DEBUG $me );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_svc;

@ISA = qw(FS::cust_main_Mixin FS::Record);

$me = '[FS::phone_avail]';
$DEBUG = 0;

=head1 NAME

FS::phone_avail - Phone number availability cache

=head1 SYNOPSIS

  use FS::phone_avail;

  $record = new FS::phone_avail \%hash;
  $record = new FS::phone_avail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::phone_avail object represents availability of phone service.
FS::phone_avail inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item availnum

primary key

=item exportnum

exportnum

=item countrycode

countrycode

=item state

state

=item npa

npa

=item nxx

nxx

=item station

station

=item name

Optional name

=item svcnum

svcnum

=item availbatch

availbatch

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'phone_avail'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('availnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum' )
    || $self->ut_number('countrycode')
    || $self->ut_alphan('state')
    || $self->ut_number('npa')
    || $self->ut_numbern('nxx')
    || $self->ut_numbern('station')
    || $self->ut_foreign_keyn('svcnum', 'cust_svc', 'svcnum' )
    || $self->ut_textn('availbatch')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_svc

=cut

sub cust_svc {
  my $self = shift;
  return '' unless $self->svcnum;
  qsearchs('cust_svc', { 'svcnum' => $self->svcnum });
}

=item part_export

=cut

sub part_export {
  my $self = shift;
  return '' unless $self->exportnum;
  qsearchs('part_export', { 'exportnum' => $self->exportnum });
}


sub process_batch_import {
  my $job = shift;

  my $numsub = sub {
    my( $phone_avail, $value ) = @_;
    $value =~ s/\D//g;
    $value =~ /^(\d{3})(\d{3})(\d+)$/ or die "unparsable number $value\n";
    #( $hash->{npa}, $hash->{nxx}, $hash->{station} ) = ( $1, $2, $3 );
    $phone_avail->npa($1);
    $phone_avail->nxx($2);
    $phone_avail->station($3);
  };

  my $opt = { 'table'   => 'phone_avail',
              'params'  => [ 'availbatch', 'exportnum', 'countrycode' ],
              'formats' => { 'default' => [ 'state', $numsub, 'name' ], },
            };

  FS::Record::process_batch_import( $job, $opt, @_ );

}

sub flush { # evil direct SQL
    my $opt = shift;

    if ( $opt->{'ratecenter'} =~ /^[\w\s]+$/
	    && $opt->{'state'} =~ /^[A-Z][A-Z]$/ 
	    && $opt->{'exportnum'} =~ /^\d+$/) {
	my $sth = dbh->prepare('delete from phone_avail where exportnum = ? '.
		    ' and state = ? and name = ?');
	$sth->execute($opt->{'exportnum'},$opt->{'state'},$opt->{'ratecenter'})
	    or die $sth->errstr;
    }

    '';
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  my $sth = dbh->prepare(
    'UPDATE phone_avail SET svcnum = NULL
       WHERE svcnum IS NOT NULL
         AND 0 = ( SELECT COUNT(*) FROM svc_phone
                     WHERE phone_avail.svcnum = svc_phone.svcnum )'
  ) or die dbh->errstr;

  $sth->execute or die $sth->errstr;

}

=back

=head1 BUGS

Sparse documentation.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

