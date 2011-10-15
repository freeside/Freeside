package FS::Maketext;

use base qw( Exporter );
use FS::CurrentUser;
use FS::Conf;
use FS::L10N;
use HTML::Entities qw( encode_entities );

our @EXPORT_OK = qw( mt emt js_mt );

our $lh;

sub mt {
  return '' if $_[0] eq '';
  $lh ||= lh();
  $lh->maketext(@_);
}

# HTML-escaped version of mt()
sub emt {
    encode_entities(mt(@_));
}

# Javascript-escaped version of mt()
sub js_mt {
  my $s = mt(@_);
  #false laziness w/Mason.pm
  $s =~ s/(['\\])/\\$1/g;
  $s =~ s/\r/\\r/g;
  $s =~ s/\n/\\n/g;
  $s = "'$s'";
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
