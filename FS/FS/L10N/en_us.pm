package FS::L10N::en_us;
use base qw(FS::L10N::DBI);

#prevents english "translation" via FS::L10N::DBI, FS::Msgcat::_gettext already
# does the same sort of fallback 
#our %Lexicon = ( _AUTO=>1 );

1;
