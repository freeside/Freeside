use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'DBIx::DBSchema',
    'VERSION_FROM' => 'DBSchema.pm', # finds $VERSION
    'PREREQ_PM'    => {
                        'DBI' => 0,
                        'FreezeThaw' => 0,
                      },
);
