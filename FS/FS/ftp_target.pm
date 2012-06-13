package FS::ftp_target;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use vars qw($me $DEBUG);

$DEBUG = 0;

=head1 NAME

FS::ftp_target - Object methods for ftp_target records

=head1 SYNOPSIS

  use FS::ftp_target;

  $record = new FS::ftp_target \%hash;
  $record = new FS::ftp_target { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::ftp_target object represents an account on a remote FTP or SFTP 
server for transferring files.  FS::ftp_target inherits from FS::Record.

=over 4

=item targetnum - primary key

=item agentnum - L<FS::agent> foreign key; can be null

=item hostname - the DNS name of the FTP site

=item username - username

=item password - password

=item path - the working directory to change to upon connecting

=item secure - a flag ('Y' or null) for whether to use SFTP

=back

=head1 METHODS

=over 4

=cut

sub table { 'ftp_target'; }

=item new HASHREF

Creates a new FTP target.  To add it to the database, see L<"insert">.

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  if ( !$self->get('port') ) {
    if ( $self->secure ) {
      $self->set('port', 22);
    } else {
      $self->set('port', 21);
    }
  }

  my $error = 
    $self->ut_numbern('targetnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('hostname')
    || $self->ut_text('username')
    || $self->ut_text('password')
    || $self->ut_number('port')
    || $self->ut_text('path')
    || $self->ut_flag('secure')
    || $self->ut_enum('handling', [ $self->handling_types ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item connect

Creates a Net::FTP or Net::SFTP::Foreign object (according to the setting
of the 'secure' flag), connects to 'hostname', attempts to log in with 
'username' and 'password', and changes the working directory to 'path'.
On success, returns the object.  On failure, dies with an error message.

=cut

sub connect {
  my $self = shift;
  if ( $self->secure ) {
    eval "use Net::SFTP::Foreign;";
    die $@ if $@;
    my %args = (
      port      => $self->port,
      user      => $self->username,
      password  => $self->password,
      more      => ($DEBUG ? '-v' : ''),
      timeout   => 30,
      autodie   => 1, #we're doing this anyway
    );
    my $sftp = Net::SFTP::Foreign->new($self->hostname, %args);
    $sftp->setcwd($self->path);
    return $sftp;
  }
  else {
    eval "use Net::FTP;";
    die $@ if $@;
    my %args = ( 
      Debug   => $DEBUG,
      Port    => $self->port,
      Passive => 1,# optional?
    );
    my $ftp = Net::FTP->new($self->hostname, %args)
      or die "connect to ".$self->hostname." failed: $@";
    $ftp->login($self->username, $self->password)
      or die "login to ".$self->username.'@'.$self->hostname." failed: $@";
    $ftp->binary; #optional?
    $ftp->cwd($self->path)
      or ($self->path eq '/')
      or die "cwd to ".$self->hostname.'/'.$self->path." failed: $@";

    return $ftp;
  }
}

=item label

Returns a descriptive label for this target.

=cut

sub label {
  my $self = shift;
  $self->targetnum . ': ' . $self->username . '@' . $self->hostname;
}

=item handling_types

Returns a list of values for the "handling" field, corresponding to the 
known ways to preprocess a file before uploading.  Currently those are 
implemented somewhat crudely in L<FS::Cron::upload>.

=cut

sub handling_types {
  '',
  #'billco', #not implemented this way yet
  'bridgestone',
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

