use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	    => 'FS::SignupClient',
    'VERSION_FROM'  => 'SignupClient.pm', # finds $VERSION
    'EXE_FILES'     => [ 'fs_signupd' ],
    'INSTALLSCRIPT' => '/usr/local/sbin',
    'INSTALLSITEBIN' => '/usr/local/sbin',
    'PERM_RWX'      => '750',
    'PREREQ_PM'     => {
                         'Business::CreditCard' => 0,
                         'HTTP::BrowserDetect' => 0,
                         'Text::Template' => 0,
                         'FS::SelfService' => 0,
                       },
);
