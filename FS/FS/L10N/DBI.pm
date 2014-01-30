package FS::L10N::DBI;
use base qw(FS::L10N);
use strict;
use FS::Msgcat;

sub lexicon {
  my $lh = shift;
  my $class = ref($lh) || $lh;
  no strict 'refs';
  \%{ $class . '::Lexicon' };
}

sub maketext {
  my($lh, $key, @rest) = @_;

  my $lang = $lh->language_tag;
  $lang =~ s/-(\w*)/_\U$1/;

  my $lex = $lh->lexicon;
  unless ( exists $lex->{$key} ) {
    $lex->{$key} = FS::Msgcat::_gettext( $key, $lang );
  }

  my $res = eval { $lh->SUPER::maketext($key, @rest) };
  if ( !$res || $@ ) {
    my $errmsg = "MT error for '$key'";
    warn "$errmsg\n";
    return $errmsg;
  }

  $res;
}

1;

