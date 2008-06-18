package FS::Msgcat;

use strict;
use vars qw( @ISA @EXPORT_OK $conf $locale $debug );
use Exporter;
use FS::UID;
#use FS::Record qw( qsearchs ); # wtf?  won't import...
use FS::Record;
#use FS::Conf; #wtf?  causes dependency loops too.
use FS::msgcat;

@ISA = qw(Exporter);
@EXPORT_OK = qw( gettext geterror );

FS::UID->install_callback( sub {
  eval "use FS::Conf;";
  die $@ if $@;
  $conf = new FS::Conf;
  $locale = $conf->config('locale') || 'en_US';
  $debug = $conf->exists('show-msgcat-codes')
});

=head1 NAME

FS::Msgcat - Message catalog functions

=head1 SYNOPSIS

  use FS::Msgcat qw(gettext geterror);

  #simple interface for retreiving messages...
  $message = gettext('msgcode');
  #or errors (includes the error code)
  $message = geterror('msgcode');

=head1 DESCRIPTION

FS::Msgcat provides functions to use the message catalog.  If you want to
maintain the message catalog database, see L<FS::msgcat> instead.

=head1 SUBROUTINES

=over 4

=item gettext MSGCODE

Returns the full message for the supplied message code.

=cut

sub gettext {
  $debug ? geterror(@_) : _gettext(@_);
}

sub _gettext {
  my $msgcode = shift;
  my $msgcat = FS::Record::qsearchs('msgcat', {
    'msgcode' => $msgcode,
    'locale' => $locale
  } );
  if ( $msgcat ) {
    $msgcat->msg;
  } else {
    warn "WARNING: message for msgcode $msgcode in locale $locale not found";
    $msgcode;
  }

}

=item geterror MSGCODE

Returns the full message for the supplied message code, including the message
code.

=cut

sub geterror {
  my $msgcode = shift;
  my $msg = _gettext($msgcode);
  if ( $msg eq $msgcode ) {
    "Error code $msgcode (message for locale $locale not found)";
  } else {
    "$msg (error code $msgcode)";
  }
}

=back

=head1 BUGS

i18n/l10n, eek

=head1 SEE ALSO

L<FS::msgcat>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

