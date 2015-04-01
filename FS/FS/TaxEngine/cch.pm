package FS::TaxEngine::cch;

use strict;
use vars qw( $DEBUG );
use base 'FS::TaxEngine';
use FS::Record qw(dbh qsearch qsearchs);
use FS::Conf;

=head1 SUMMARY

FS::TaxEngine::cch - CCH published tax tables.  Uses multiple tables:
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

=item add_sale LINEITEM

Takes LINEITEM (a L<FS::cust_bill_pkg> object) and adds it to three internal
data structures:

- C<items>, an arrayref of all items on this invoice.
- C<taxes>, a hashref of taxnum => arrayref containing the items that are
  taxable under that tax definition.
- C<taxclass>, a hashref of taxnum => arrayref containing the tax class
  names parallel to the C<taxes> array for the same tax.

The item will appear on C<taxes> once for each tax class (setup, recur,
or a usage class number) that's taxable under that class and appears on
the item.

C<add_sale> will also determine any exemptions that apply to the item
and attach them to LINEITEM.

=cut

sub add_sale {
  my ($self, $cust_bill_pkg) = @_;

  my $part_item = $cust_bill_pkg->part_X;
  my $location = $cust_bill_pkg->tax_location;
  my $custnum = $self->{cust_main}->custnum;

  push @{ $self->{items} }, $cust_bill_pkg;

  my $conf = FS::Conf->new;

  my @classes;
  my $usage = $cust_bill_pkg->usage || 0;
  push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->usage;
  if (!$self->{cancel}) {
    push @classes, 'setup' if $cust_bill_pkg->setup > 0;
    push @classes, 'recur' if ($cust_bill_pkg->recur - $usage) > 0;
  }

  # About $self->{cancel}: This protects against charging per-line or
  # per-customer or other flat-rate surcharges on a package that's being
  # billed on cancellation (which is an out-of-cycle bill and should only
  # have usage charges).  See RT#29443.

  # only calculate exemptions once for each tax rate, even if it's used for
  # multiple classes.
  my %tax_seen;

  foreach my $class (@classes) {
    my $err_or_ref = $self->_gather_taxes($part_item, $class, $location);
    return $err_or_ref unless ref($err_or_ref);
    my @taxes = @$err_or_ref;

    next if !@taxes;

    foreach my $tax (@taxes) {
      my $taxnum = $tax->taxnum;
      $self->{taxes}{$taxnum} ||= [];
      $self->{taxclass}{$taxnum} ||= [];
      push @{ $self->{taxes}{$taxnum} }, $cust_bill_pkg;
      push @{ $self->{taxclass}{$taxnum} }, $class;

      if ( !$tax_seen{$taxnum} ) {
        $cust_bill_pkg->set_exemptions( $tax, 'custnum' => $custnum );
        $tax_seen{$taxnum}++;
      }
    } #foreach $tax
  } #foreach $class
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

# differs from stock make_taxlines because we need another pass to do
# tax on tax
sub make_taxlines {
  my $self = shift;
  my $cust_bill = shift;

  my @raw_taxlines;
  my %taxable_location; # taxable billpkgnum => cust_location
  my %item_has_tax; # taxable billpkgnum => taxnum
  foreach my $taxnum ( keys %{ $self->{taxes} } ) {
    my $tax_rate = FS::tax_rate->by_key($taxnum);
    my $taxables = $self->{taxes}{$taxnum};
    my $charge_classes = $self->{taxclass}{$taxnum};
    foreach (@$taxables) {
      $taxable_location{ $_->billpkgnum } ||= $_->tax_location;
    }

    my @taxlines = $tax_rate->taxline_cch( $taxables, $charge_classes );

    next if !@taxlines;
    if (!ref $taxlines[0]) {
      # it's an error string
      warn "error evaluating tax#$taxnum\n";
      return $taxlines[0];
    }

    my $billpkgnum = -1; # the current one
    my $fragments; # $item_has_tax{$billpkgnum}{taxnum}

    foreach my $taxline (@taxlines) {
      next if $taxline->setup == 0;

      my $link = $taxline->get('cust_bill_pkg_tax_rate_location')->[0];
      # store this tax fragment, indexed by taxable item, then by taxnum
      if ( $billpkgnum != $link->taxable_billpkgnum ) {
        $billpkgnum = $link->taxable_billpkgnum;
        $item_has_tax{$billpkgnum} ||= {};
        $fragments = $item_has_tax{$billpkgnum}{$taxnum} ||= [];
      }

      $taxline->set('invnum', $cust_bill->invnum);
      push @$fragments, $taxline; # so we can ToT it
      push @raw_taxlines, $taxline; # so we actually bill it
    }
  } # foreach $taxnum

  # all first-tier taxes are calculated. now for tax on tax
  # (has to be done on a per-taxable-item basis)
  foreach my $billpkgnum (keys %item_has_tax) {
    # taxes that apply to this item
    my $this_has_tax = $item_has_tax{$billpkgnum};
    my $location = $taxable_location{$billpkgnum};
    foreach my $taxnum (keys %$this_has_tax) {
      my $tax_rate = FS::tax_rate->by_key($taxnum);
      # find all taxes that apply to it in this location
      my @tot = $tax_rate->tax_on_tax( $location );
      next if !@tot;

      warn "found possible taxed taxnum $taxnum\n"
        if $DEBUG > 2;
      # Calculate ToT separately for each taxable item, and only if _that 
      # item_ is already taxed under the ToT.  This is counterintuitive.
      # See RT#5243.
      foreach my $tot (@tot) { 
        my $totnum = $tot->taxnum;
        warn "checking taxnum ".$tot->taxnum. 
             " which we call ". $tot->taxname ."\n"
          if $DEBUG > 2;
        if ( exists $this_has_tax->{ $totnum } ) {
          warn "calculating tax on tax: taxnum ".$tot->taxnum." on $taxnum\n"
            if $DEBUG; 
          my @taxlines = $tot->taxline_cch(
            $this_has_tax->{ $taxnum }, # the first-stage tax (in an arrayref)
          );
          next if (!@taxlines); # it didn't apply after all
          if (!ref($taxlines[0])) {
            warn "error evaluating TOT ($totnum on $taxnum)\n";
            return $taxlines[0];
          }
          # add these to the taxline queue
          push @raw_taxlines, @taxlines;
        } # if $this_has_tax->{$totnum}
      } # foreach my $tot (tax-on-tax rate definition)
    } # foreach $taxnum (first-tier rate definition)
  } # foreach $taxable_item

  return @raw_taxlines;
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
