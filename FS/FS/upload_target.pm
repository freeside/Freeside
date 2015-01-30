package FS::upload_target;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw(send_email);
use FS::Conf;
use File::Spec;
use vars qw($me $DEBUG);

$DEBUG = 0;

=head1 NAME

FS::upload_target - Object methods for upload_target records

=head1 SYNOPSIS

  use FS::upload_target;

  $record = new FS::upload_target \%hash;
  $record = new FS::upload_target { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::upload_target object represents a destination to deliver files (such 
as invoice batches) by FTP, SFTP, or email.  FS::upload_target inherits from
FS::Record.

=over 4

=item targetnum - primary key

=item agentnum - L<FS::agent> foreign key; can be null

=item protocol - 'ftp', 'sftp', or 'email'.

=item hostname - the DNS name of the FTP site, or the domain name of the 
email address.

=item port - the TCP port number, if it's not standard.

=item username - username

=item password - password

=item path - for FTP/SFTP, the working directory to change to upon connecting.

=item subject - for email, the Subject: header

=item handling - a string naming an additional process to apply to
the file before sending it.

=back

=head1 METHODS

=over 4

=cut

sub table { 'upload_target'; }

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

  my $protocol = lc($self->protocol);
  if ( $protocol eq 'email' ) {
    $self->set(password => '');
    $self->set(port => '');
    $self->set(path => '');
  } elsif ( $protocol eq 'sftp' ) {
    $self->set(port => 22) unless $self->get('port');
    $self->set(subject => '');
  } elsif ( $protocol eq 'ftp' ) {
    $self->set('port' => 21) unless $self->get('port');
    $self->set(subject => '');
  } else {
    return "protocol '$protocol' not supported";
  }
  $self->set(protocol => $protocol); # lowercase it

  my $error = 
    $self->ut_numbern('targetnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('hostname')
    || $self->ut_text('username')
    || $self->ut_textn('password')
    || $self->ut_numbern('port')
    || $self->ut_textn('path')
    || $self->ut_textn('subject')
    || $self->ut_enum('handling', [ $self->handling_types ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item put LOCALNAME [ REMOTENAME ]

Uploads the file named LOCALNAME, optionally changing its name to REMOTENAME
on the target.  For FTP/SFTP, this opens a connection, changes to the working
directory (C<path>), and PUTs the file.  For email, it composes an empty 
message and attaches the file.

Returns an error message if anything goes wrong.

=cut

sub put {
  my $self = shift;
  my $localname = shift;
  my @s = File::Spec->splitpath($localname);
  my $remotename = shift || $s[-1];

  my $conf = FS::Conf->new;
  if ( $self->protocol eq 'ftp' or $self->protocol eq 'sftp' ) {
    # could cache this if we ever want to reuse it
    local $@;
    my $connection = eval { $self->connect };
    return $@ if $@;
    $connection->put($localname, $remotename);
    return $connection->error || '';
  } elsif ( $self->protocol eq 'email' ) {

    my $to = join('@', $self->username, $self->hostname);
    # XXX if we were smarter, this could use a message template for the 
    # message subject, body, and source address
    # (maybe use only the raw content, so that we don't have to supply a 
    # customer for substitutions? ewww.)
    my %message = (
      'from'          => $conf->invoice_from_full(),
      'to'            => $to,
      'subject'       => $self->subject,
      'nobody'        => 1,
      'mimeparts'     => [
        { Path            => $localname,
          Type            => 'application/octet-stream',
          Encoding        => 'base64',
          Filename        => $remotename,
          Disposition     => 'attachment',
        }
      ],
    );
    return send_email(%message);

  } else {
    return "unknown protocol '".$self->protocol."'";
  }
}

=item connect

Creates a Net::FTP or Net::SFTP::Foreign object (according to the setting
of the 'secure' flag), connects to 'hostname', attempts to log in with 
'username' and 'password', and changes the working directory to 'path'.
On success, returns the object.  On failure, dies with an error message.

Always returns an error for email targets.

=cut

sub connect {
  my $self = shift;
  if ( $self->protocol eq 'sftp' ) {
    eval "use Net::SFTP::Foreign;";
    die $@ if $@;
    my %args = (
      user      => $self->username,
      timeout   => 30,
      autodie   => 0, #we're doing this anyway
    );
    # Net::SFTP::Foreign does not deal well with args that are defined
    # but empty
    $args{port} = $self->port if $self->port and $self->port != 22;
    $args{password} = $self->password if length($self->password) > 0;
    $args{more} = '-v' if $DEBUG;
    my $sftp = Net::SFTP::Foreign->new($self->hostname, %args);
    $sftp->setcwd($self->path);
    return $sftp;
  }
  elsif ( $self->protocol eq 'ftp') {
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
  } else {
    return "can't connect() to a target of type '".$self->protocol."'";
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
  'ics',
}

=back

=head1 BUGS

Handling methods should be here, but instead are in FS::Cron.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

