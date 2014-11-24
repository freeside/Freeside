package FS::TaxEngine::cch;

use strict;
use vars qw( $DEBUG );
use base 'FS::TaxEngine';
use FS::Record qw(dbh qsearch qsearchs);
use FS::Conf;

=head1 SUMMARY

FS::TaxEngine::cch CCH published tax tables.  Uses multiple tables:
- tax_rate: definition of specific taxes, based on tax class and geocode.
- cust_tax_location: definition of geocodes, using zip+4 codes.
- tax_class: definition of tax classes.
- part_pkg_taxproduct: definition of taxable products (foreign key in 
  part_pkg.taxproductnum and the "usage_taxproductnum_*" part_pkg options).
  The 'taxproduct' string in this table can implicitly include other 
  taxproducts.
- part_pkg_taxrate: links (geocode, taxproductnum) of a sold product to a 
  tax class.  Many records here have partial-length geocodes which act
  as wildcards.
- part_pkg_taxoverride: manual link from a part_pkg to a specific tax class.

=cut

$DEBUG = 0;

my %part_pkg_cache;

sub add_sale {
  my ($self, $cust_bill_pkg, %options) = @_;

  my $part_item = $options{part_item} || $cust_bill_pkg->part_X;
  my $location = $options{location} || $cust_bill_pkg->tax_location;

  push @{ $self->{items} }, $cust_bill_pkg;

  my $conf = FS::Conf->new;

  my @classes;
  push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->usage;
  # debatable
  push @classes, 'setup' if ($cust_bill_pkg->setup && !$self->{cancel});
  push @classes, 'recur' if ($cust_bill_pkg->recur && !$self->{cancel});

  my %taxes_for_class;

  my $exempt = $conf->exists('cust_class-tax_exempt')
                  ? ( $self->cust_class ? $self->cust_class->tax : '' )
                  : $self->{cust_main}->tax;
  # standardize this just to be sure
  $exempt = ($exempt eq 'Y') ? 'Y' : '';

  if ( !$exempt ) {

    foreach my $class (@classes) {
      my $err_or_ref = $self->_gather_taxes( $part_item, $class, $location );
      return $err_or_ref unless ref($err_or_ref);
      $taxes_for_class{$class} = $err_or_ref;
    }
    unless (exists $taxes_for_class{''}) {
      my $err_or_ref = $self->_gather_taxes( $part_item, '', $location );
      return $err_or_ref unless ref($err_or_ref);
      $taxes_for_class{''} = $err_or_ref;
    }

  }

  my %tax_cust_bill_pkg = $cust_bill_pkg->disintegrate; # grrr
  foreach my $key (keys %tax_cust_bill_pkg) {
    # $key is "setup", "recur", or a usage class name. ('' is a usage class.)
    # $tax_cust_bill_pkg{$key} is a cust_bill_pkg for that component of 
    # the line item.
    # $taxes_for_class{$key} is an arrayref of tax_rate objects that
    # apply to $key-class charges.
    my @taxes = @{ $taxes_for_class{$key} || [] };
    my $tax_cust_bill_pkg = $tax_cust_bill_pkg{$key};

    my %localtaxlisthash = ();
    foreach my $tax ( @taxes ) {

      my $taxnum = $tax->taxnum;
      $self->{taxes}{$taxnum} ||= [ $tax ];
      push @{ $self->{taxes}{$taxnum} }, $tax_cust_bill_pkg;

      $localtaxlisthash{ $taxnum } ||= [ $tax ];
      push @{ $localtaxlisthash{$taxnum} }, $tax_cust_bill_pkg;

    }

    warn "finding taxed taxes...\n" if $DEBUG > 2;
    foreach my $taxnum ( keys %localtaxlisthash ) {
      my $tax_object = shift @{ $localtaxlisthash{$taxnum} };

      foreach my $tot ( $tax_object->tax_on_tax( $location ) ) {
        my $totnum = $tot->taxnum;

        # I'm not sure why, but for some reason we only add ToT if that 
        # tax_rate already applies to a non-tax item on the same invoice.
        next unless exists( $localtaxlisthash{ $totnum } );
        warn "adding #$totnum to taxed taxes\n" if $DEBUG > 2;
        # calculate the tax amount that the tax_on_tax will apply to
        my $taxline =
          $self->taxline( 'tax' => $tax_object,
                          'sales' => $localtaxlisthash{$taxnum}
                        );
        return $taxline unless ref $taxline;
        # and append it to the list of taxable items
        $self->{taxes}->{$totnum} ||= [ $tot ];
        push @{ $self->{taxes}->{$totnum} }, $taxline->setup;

      } # foreach $tot (tax-on-tax)
    } # foreach $tax
  } # foreach $key (i.e. usage class)
}

sub _gather_taxes { # interface for this sucks
  my $self = shift;
  my $part_item = shift;
  my $class = shift;
  my $location = shift;

  my $geocode = $location->geocode('cch');

  my @taxes = $part_item->tax_rates('cch', $geocode, $class);

  warn "Found taxes ".
       join(',', map{ ref($_). " ". $_->get($_->primary_key) } @taxes). "\n"
   if $DEBUG;

  \@taxes;

}

sub taxline {
  # FS::tax_rate::taxline() ridiculously returns a description and amount 
  # instead of a real line item.  Fix that here.
  #
  # XXX eventually move the code from tax_rate to here
  # but that's not necessary yet
  my ($self, %opt) = @_;
  my $tax_object = $opt{tax};
  my $taxables = $opt{sales};
  my $hashref = $tax_object->taxline_cch($taxables);
  return $hashref unless ref $hashref; # it's an error message

  my $tax_amount = sprintf('%.2f', $hashref->{amount});
  my $tax_item = FS::cust_bill_pkg->new({
      'itemdesc'  => $hashref->{name},
      'pkgnum'    => 0,
      'recur'     => 0,
      'sdate'     => '',
      'edate'     => '',
      'setup'     => $tax_amount,
  });
  my $tax_link = FS::cust_bill_pkg_tax_rate_location->new({
      'taxnum'              => $tax_object->taxnum,
      'taxtype'             => ref($tax_object), #redundant
      'amount'              => $tax_amount,
      'locationtaxid'       => $tax_object->location,
      'taxratelocationnum'  =>
          $tax_object->tax_rate_location->taxratelocationnum,
      'tax_cust_bill_pkg'   => $tax_item,
      # XXX still need to get taxable_cust_bill_pkg in here
      # but that requires messing around in the taxline code
  });
  $tax_item->set('cust_bill_pkg_tax_rate_location', [ $tax_link ]);

  return $tax_item;
}

sub cust_tax_locations {
  my $class = shift;
  my $location = shift;
  $location = FS::cust_location->new($location) if ref($location) eq 'HASH';

  # limit to CCH zip code prefix records, not zip+4 range records
  my $hashref = { 'data_vendor' => 'cch-zip' };
  if ( $location->country eq 'CA' ) {
    # weird CCH convention: treat Canadian provinces as localities, using
    # their one-letter postal codes.
    $hashref->{zip} = substr($location->zip, 0, 1);
  } elsif ( $location->country eq 'US' ) {
    $hashref->{zip} = substr($location->zip, 0, 5);
  } else {
    return ();
  }

  return qsearch('cust_tax_location', $hashref);
}

sub info {
 +{
    batch               => 0,
    override            => 1,
    manual_tax_location => 1,
    rate_table          => 'tax_rate',
    link_table          => 'cust_bill_pkg_tax_rate_location',
  }
}

1; 
