package FS::part_pkg::flat_comission_pkg;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;

@ISA = qw(FS::part_pkg);

%info = (
    'name' => 'Flat rate with recurring commission per (selected) active package',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                     },
      'comission_amount' => { 'name' => 'Commission amount per month (per uncancelled package)',
                              'default' => 0,
                            },
      'comission_depth'  => { 'name' => 'Number of layers',
                              'default' => 1,
                            },
      'comission_pkgpart' => { 'name' => 'Applicable packages<BR><FONT SIZE="-1">(hold <b>ctrl</b> to select multiple packages)</FONT>',
                               'type' => 'select_multiple',
                               'select_table' => 'part_pkg',
                               'select_hash'  => { 'disabled' => '' } ,
                               'select_key'   => 'pkgpart',
                               'select_label' => 'pkg',
                             },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee', 'comission_depth', 'comission_amount', 'comission_pkgpart' ],
    #'setup' => 'what.setup_fee.value',
    #'recur' => '""; var pkgparts = ""; for ( var c=0; c < document.flat_comission_pkg.comission_pkgpart.options.length; c++ ) { if (document.flat_comission_pkg.comission_pkgpart.options[c].selected) { pkgparts = pkgparts + document.flat_comission_pkg.comission_pkgpart.options[c].value + \', \'; } } what.recur.value = \'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar( grep { my $pkgpart = $_->pkgpart; grep { $_ == $pkgpart } ( \' + pkgparts + \'  ) } $cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
    #'disabled' => 1,
    'weight' => '64',
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my($self, $cust_pkg ) = @_;
  $self->option('recur_fee');
}

1;
