use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'FS::SessionClient',
    'VERSION_FROM'  => 'SessionClient.pm', # finds $VERSION
    'EXE_FILES'     => [ 'fs_sessiond' ],
    'INSTALLSCRIPT' => '/usr/local/sbin',
    'PERM_RWX'      => '750',
);
