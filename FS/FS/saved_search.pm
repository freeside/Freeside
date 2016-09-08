package FS::saved_search;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::Log;
use FS::Misc qw(send_email);
use MIME::Entity;
use Class::Load 'load_class';
use URI::Escape;
use DateTime;

=head1 NAME

FS::saved_search - Object methods for saved_search records

=head1 SYNOPSIS

  use FS::saved_search;

  $record = new FS::saved_search \%hash;
  $record = new FS::saved_search { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::saved_search object represents a search (a page in the backoffice
UI, typically under search/ or browse/) which a user has saved for future
use or periodic email delivery.

FS::saved_search inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item searchnum

primary key

=item usernum

usernum of the L<FS::access_user> that created the search. Currently, email
reports will only be sent to this user.

=item searchname

A descriptive name.

=item path

The path to the page within the Mason document space.

=item params

The query string for the search.

=item disabled

'Y' to hide the search from the user's Reports / Saved menu.

=item freq

A frequency for email delivery of this report: daily, weekly, or
monthly, or null to disable it.

=item last_sent

The timestamp of the last time this report was sent.

=item format

'html', 'xls', or 'csv'. Not all reports support all of these.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new saved search.  To add it to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'saved_search'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('searchnum')
    || $self->ut_number('usernum')
    #|| $self->ut_foreign_keyn('usernum', 'access_user', 'usernum')
    || $self->ut_text('searchname')
    || $self->ut_text('path')
    || $self->ut_textn('params') # URL-escaped, so ut_textn
    || $self->ut_flag('disabled')
    || $self->ut_enum('freq', [ '', 'daily', 'weekly', 'monthly' ])
    || $self->ut_numbern('last_sent')
    || $self->ut_enum('format', [ '', 'html', 'csv', 'xls' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub replace_check {
  my ($new, $old) = @_;
  if ($new->usernum != $old->usernum) {
    return "can't change owner of a saved search";
  }
  '';
}

=item next_send_date

Returns the next date this report should be sent next. If it's not set for
periodic email sending, returns undef. If it is set up but has never been
sent before, returns zero.

=cut

sub next_send_date {
  my $self = shift;
  my $freq = $self->freq or return undef;
  return 0 unless $self->last_sent;
  my $dt = DateTime->from_epoch(epoch => $self->last_sent);
  $dt->truncate(to => 'day');
  if ($freq eq 'daily') {
    $dt->add(days => 1);
  } elsif ($freq eq 'weekly') {
    $dt->add(weeks => 1);
  } elsif ($freq eq 'monthly') {
    $dt->add(months => 1);
  }
  $dt->epoch;
}

=item query_string

Returns the CGI query string for the parameters to this report.

=cut

sub query_string {
  my $self = shift;

  my $type = $self->format;
  $type = 'html-print' if $type eq '' || $type eq 'html';
  $type = '.xls' if $type eq 'xls';
  my $query = "_type=$type";
  $query .= ';' . $self->params if $self->params;
  $query;
}

=item render

Returns the report content as an HTML or Excel file.

=cut

sub render {
  my $self = shift;
  my $log = FS::Log->new('FS::saved_search::render');
  my $outbuf;

  # delayed loading
  load_class('FS::Mason');
  RT::LoadConfig();
  RT::Init();

  # do this before setting QUERY_STRING/FSURL
  my ($fs_interp) = FS::Mason::mason_interps('standalone',
    outbuf => \$outbuf
  );
  $fs_interp->error_mode('fatal');
  $fs_interp->error_format('text');

  local $FS::CurrentUser::CurrentUser = $self->access_user;
  local $FS::Mason::Request::QUERY_STRING = $self->query_string;
  local $FS::Mason::Request::FSURL = $self->access_user->option('rooturl');

  my $mason_request = $fs_interp->make_request(comp => '/' . $self->path);
  $mason_request->notes('inline_stylesheet', 1);

  local $@;
  eval { $mason_request->exec(); };
  if ($@) {
    my $error = $@;
    if ( ref($error) eq 'HTML::Mason::Exception' ) {
      $error = $error->message;
    }

    $log->error("Error rendering " . $self->path .
         " for " . $self->access_user->username .
         ":\n$error\n");
    # send it to the user anyway, so there's a way to diagnose the error
    $outbuf = '<h3>Error</h3>
  <p>There was an error generating the report "'.$self->searchname.'".</p>
  <p>' . $self->path . '?' . $self->query_string . '</p>
  <p>' . $_ . '</p>';
  }

  my %mime = (
    Data        => $outbuf,
    Type        => $mason_request->notes('header-content-type')
                   || 'text/html',
    Disposition => 'inline',
  );
  if (my $disp = $mason_request->notes('header-content-disposition') ) {
    $disp =~ /^(attachment|inline)\s*;\s*filename=(.*)$/;
    $mime{Disposition} = $1;
    my $filename = $2;
    $filename =~ s/^"(.*)"$/$1/;
    $mime{Filename} = $filename;
  }
  if ($mime{Type} =~ /^text/) {
    $mime{Encoding} = 'quoted-printable';
  } else {
    $mime{Encoding} = 'base64';
  }
  return MIME::Entity->build(%mime);
}

=item send

Sends the search by email. If anything fails, logs and returns an error.

=cut

sub send {
  my $self = shift;
  my $log = FS::Log->new('FS::saved_search::send');
  my $conf = FS::Conf->new;
  my $user = $self->access_user;
  my $username = $user->username;
  my $user_email = $user->option('email_address');
  my $error;
  if (!$user_email) {
    $error = "User '$username' has no email address.";
    $log->error($error);
    return $error;
  }
  $log->debug('Rendering saved search');
  my $part = $self->render;

  my %email_param = (
    'from'      => $conf->config('invoice_from'),
    'to'        => $user_email,
    'subject'   => $self->searchname,
    'nobody'    => 1,
    'mimeparts' => [ $part ],
  );

  $log->debug('Sending to '.$user_email);
  $error = send_email(%email_param);

  # update the timestamp
  $self->set('last_sent', time);
  $error ||= $self->replace;
  if ($error) {
    $log->error($error);
    return $error;
  }

}

sub queueable_send {
  my $searchnum = shift;
  my $self = FS::saved_search->by_key($searchnum)
    or die "searchnum $searchnum not found\n";
  $self->send;
}

#3.x
sub access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->usernum });
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

