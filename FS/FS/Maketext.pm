package FS::Maketext;

use base qw( Exporter );
use FS::CurrentUser;
use FS::Conf;
use FS::L10N;
use HTML::Entities qw( encode_entities );

our @EXPORT_OK = qw( mt emt );

our $lh;

sub mt {
  $lh ||= lh();
  $lh->maketext(@_);
}

# HTML-escaped version of mt()
sub emt {
    encode_entities(mt(@_));
}

sub lh {
  my $locale =  $FS::CurrentUser::CurrentUser->option('locale')
             || FS::Conf->new->config('locale')
             || 'en_US';
  $locale =~ s/_/-/g;
  FS::L10N->get_handle($locale) || die "Unknown locale $locale";
}

# XXX pod me

1;
