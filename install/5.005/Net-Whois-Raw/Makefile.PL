#!/usr/bin/perl -w

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
        package MY;
        shift->SUPER::postamble . <<'MAKE';
dist : README

README : lib/Net/Whois/Raw.pm
	@$(PERL) -MPod::Text -e "pod2text('$<');" > $@

MAKE
}

WriteMakefile(
    'NAME'	=> 'Net::Whois::Raw',
    'VERSION_FROM' => 'lib/Net/Whois/Raw.pm', # finds $VERSION
    'PREREQ_PM' => {'IO::Socket' => 1.0},
    'EXE_FILES' => ['pwhois'],
    'dist' => {'COMPRESS' => 'gzip --best --force'},
);
