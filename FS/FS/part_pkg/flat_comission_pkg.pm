package FS::part_pkg::flat_comission_pkg;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Flat rate with recurring commission per (selected) active package',
  'shortname' => 'Commission per (selected) active package',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                   },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
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
    'reason_type'       => { 'name' => 'Reason type for commission credits',
                             'type' => 'select',
                             'select_table' => 'reason_type',
                             'select_hash'  => { 'class' => 'R' } ,
                             'select_key'   => 'typenum',
                             'select_label' => 'type',
                           },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit', 'comission_depth', 'comission_amount', 'comission_pkgpart', 'reason_type' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '""; var pkgparts = ""; for ( var c=0; c < document.flat_comission_pkg.comission_pkgpart.options.length; c++ ) { if (document.flat_comission_pkg.comission_pkgpart.options[c].selected) { pkgparts = pkgparts + document.flat_comission_pkg.comission_pkgpart.options[c].value + \', \'; } } what.recur.value = \'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar( grep { my $pkgpart = $_->pkgpart; grep { $_ == $pkgpart } ( \' + pkgparts + \'  ) } $cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  #'disabled' => 1,
  'weight' => '64',
);

# XXX this needs to be fixed!!!
sub calc_recur {
  my($self, $cust_pkg ) = @_;
  $self->option('recur_fee');
}

sub can_discount { 0; }

1;
