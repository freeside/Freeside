package FS::acct_snarf;

use strict;
use vars qw( @ISA );
use Tie::IxHash;
use FS::Record qw( qsearchs );
use FS::cust_svc;

@ISA = qw( FS::Record );

=head1 NAME

FS::acct_snarf - Object methods for acct_snarf records

=head1 SYNOPSIS

  use FS::acct_snarf;

  $record = new FS::acct_snarf \%hash;
  $record = new FS::acct_snarf { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_acct object represents an external mail account, typically for
download of mail.  FS::acct_snarf inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item snarfnum - primary key

=item snarfname - Label

=item svcnum - Account (see L<FS::svc_acct>)

=item machine - external machine to download mail from

=item protocol - protocol (pop3, imap, etc.)

=item username - external login username

=item _password - external login password

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'acct_snarf'; }

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

=item cust_svc

=cut

sub cust_svc {
  my $self = shift;
  qsearchs('cust_svc', { 'svcnum' => $self->svcnum } );
}


=item svc_export

Calls the replace export for any communigate exports attached to this rule's
service.

=cut

sub svc_export {
  my $self = shift;

  my $cust_svc = $self->cust_svc;
  my $svc_x = $cust_svc->svc_x;
  
  #_singledomain too
  my @exports = $cust_svc->part_svc->part_export('communigate_pro');
  my @errors = map $_->export_replace($svc_x, $svc_x), @exports;

  @errors ? join(' / ', @errors) : '';

}

=item check

Checks all fields to make sure this is a valid external mail account.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;
  my $error =
       $self->ut_numbern('snarfnum')
    || $self->ut_textn('snarfname') #alphasn?
    || $self->ut_number('svcnum')
    || $self->ut_foreign_key('svcnum', 'svc_acct', 'svcnum')
    || $self->ut_domain('machine')
    || $self->ut_alphan('protocol')
    || $self->ut_textn('username')
    || $self->ut_numbern('check_freq')
    || $self->ut_enum('leavemail', [ '', 'Y' ])
    || $self->ut_enum('apop', [ '', 'Y' ])
    || $self->ut_enum('tls', [ '', 'Y' ])
    || $self->ut_alphan('mailbox')
  ;
  return $error if $error;

  $self->_password =~ /^[^\t\n]*$/ or return "illegal password";
  $self->_password($1);

  ''; #no error
}

sub check_freq_labels {

  tie my %hash, 'Tie::IxHash',
    0 => 'Never',
    60 => 'minute',
    120 => '2 minutes',
    180 => '3 minutes',
    300 => '5 minutes',
    600 => '10 minutes',
    900 => '15 minutes',
    1800 => '30 minutes',
    3600 => 'hour',
    7200 => '2 hours',
    10800 => '3 hours',
    21600 => '6 hours',
    43200 => '12 hours',
    86400 => 'day',
    172800 => '2 days',
    259200 => '3 days',
    604800 => 'week',
    1000000000 => 'Disabled',
  ;

  \%hash;
}

=item cgp_hashref

Returns a hashref representing this external mail account, suitable for
Communigate Pro API commands:

=cut

sub cgp_hashref {
  my $self = shift;
  {
    'authName' => $self->username,
    'domain'   => $self->machine,
    'password' => $self->_password,
    'period'   => $self->check_freq.'s',
    'APOP'     => ( $self->apop      eq 'Y' ? 'YES' : 'NO' ),
    'TLS'      => ( $self->tls       eq 'Y' ? 'YES' : 'NO' ),
    'Leave'    => ( $self->leavemail eq 'Y' ? 'YES' : 'NO' ), #XXX leave??
  };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

