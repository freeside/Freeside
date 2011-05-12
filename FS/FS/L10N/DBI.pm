package FS::L10N::DBI;
use base qw(FS::L10N);
use strict;
use FS::Msgcat;

our %Lexicon = ();

sub maketext {
  my($lh, $key, @rest) = @_;

  unless ( exists $Lexicon{$key} ) {
    my $lang = $lh->language_tag;
    $lang =~ s/-(\w*)/_\U$1/;
    $Lexicon{$key} = FS::Msgcat::_gettext( $key, $lang );
  }

  $lh->SUPER::maketext($key, @rest);

}

1;

