use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'FS::SelfService',
    'VERSION_FROM'	=> 'SelfService.pm', # finds $VERSION
    'EXE_FILES'         => [ 'freeside-selfservice-clientd',
                             'freeside-selfservice-soap-server',
                             'freeside-selfservice-xmlrpc-server',
                           ],
    'INSTALLSCRIPT'     => '/usr/local/sbin',
    'INSTALLSITEBIN'    => '/usr/local/sbin',
    'INSTALLSITESCRIPT' => '/usr/local/sbin', #recent deb users this...
    'PERM_RWX'          => '750',
    'PREREQ_PM'		=> {
                             'Storable' => 2.09,
                           }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'SelfService.pm', # retrieve abstract from module
       AUTHOR     => 'Ivan Kohler <ivan-freeside-selfservice@420.am>') : ()),
);
