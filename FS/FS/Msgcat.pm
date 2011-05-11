package FS::Msgcat;

use strict;
use vars qw( @ISA @EXPORT_OK $conf $def_locale $debug );
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
  $def_locale = $conf->config('locale') || 'en_US';
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

#though i guess we don't really have to cache here since we do it in
# FS::L10N::DBI
our %cache;

sub _gettext {
  my $msgcode = shift;
  my $locale =  (@_ && shift)
             || $FS::CurrentUser::CurrentUser->option('locale')
             || $def_locale;

  return $cache{$locale}->{$msgcode} if exists $cache{$locale}->{$msgcode};

  my $msgcat = FS::Record::qsearchs('msgcat', {
    'msgcode' => $msgcode,
    'locale'  => $locale,
  } );
  if ( $msgcat ) {
    $cache{$locale}->{$msgcode} = $msgcat->msg;
  } else {
    warn "WARNING: message for msgcode $msgcode in locale $locale not found"
      unless $locale eq 'en_US';
    $cache{$locale}->{$msgcode} = $msgcode;
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
    my $locale = $FS::CurrentUser::CurrentUser->option('locale') || $def_locale;
    "Error code $msgcode (message for locale $locale not found)";
  } else {
    "$msg (error code $msgcode)";
  }
}

=back

=head1 BUGS

i18n/l10n, eek

=head1 SEE ALSO

L<FS::Locales>, L<FS::msgcat>

=cut

1;

