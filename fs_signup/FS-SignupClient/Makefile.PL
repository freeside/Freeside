use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	    => 'FS::SignupClient',
    'VERSION_FROM'  => 'SignupClient.pm', # finds $VERSION
    'EXE_FILES'     => [ 'fs_signupd' ],
    'INSTALLSCRIPT' => '/usr/local/sbin',
    'PERM_RWX'      => '750',
);
