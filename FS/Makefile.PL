use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	   => 'FS',
    'VERSION_FROM' => 'FS.pm', # finds $VERSION
    'EXE_FILES'    => [ glob 'bin/*' ],
    'INSTALLSCRIPT'  => '/usr/local/bin',
    'INSTALLSITEBIN' => '/usr/local/bin',
);
