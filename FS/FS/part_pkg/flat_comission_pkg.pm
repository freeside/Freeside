package FS::part_pkg::flat_comission_pkg;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Flat rate with recurring commission per (selected) active package',
  'shortname' => 'Commission per (selected) active package',
  'inherit_fields' => [ 'flat_comission', 'global_Mixin' ],
  'fields' => {
    'comission_pkgpart' => { 'name' => 'Applicable packages<BR><FONT SIZE="-1">(hold <b>ctrl</b> to select multiple packages)</FONT>',
                             'type' => 'select_multiple',
                             'select_table' => 'part_pkg',
                             'select_hash'  => { 'disabled' => '' } ,
                             'select_key'   => 'pkgpart',
                             'select_label' => 'pkg',
                           },
  },
  'fieldorder' => [ 'comission_depth', 'comission_amount', 'comission_pkgpart', 'reason_type' ],
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
