use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share dist => 'share';

WriteMakefile(
    NAME             => 'FS::Test',
    AUTHOR           => q{Mark Wells <mark@freeside.biz>},
    VERSION_FROM     => 'lib/FS/Test.pm',
    ABSTRACT         => 'Freeside test suite', 
    LICENSE          => 'agpl_3',
    PL_FILES         => {},
    EXE_FILES        => [ glob 'bin/*' ],
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'File::ShareDir::Install' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'WWW::Mechanize' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'FS-Test-*' },
);

package MY;
use File::ShareDir::Install qw(postamble);

