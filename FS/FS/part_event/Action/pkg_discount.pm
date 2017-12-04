package FS::part_event::Action::pkg_discount;

use strict;
use base qw( FS::part_event::Action );

sub description { "Discount unsuspended package(s) (monthly recurring only)"; }

sub eventtable_hashref {
  { 'cust_main' => 1,
    'cust_pkg'  => 1,
  };
}

sub event_stage { 'pre-bill'; }

sub option_fields {
  (
    'if_pkgpart'  => { 'label'    => 'Only packages',
                       'type'     => 'select-table',
                       'table'    => 'part_pkg',
                       'name_col' => 'pkg',
                       #can tweak after fixing discount bug with non-monthly recurring pkgs 
                       'extra_sql' => q(AND freq NOT LIKE '0%' AND freq NOT LIKE '%d' AND freq NOT LIKE '%h' AND freq NOT LIKE '%w'), 
                       'multiple' => 1,
                     },
    'if_pkg_class' => { 'label'    => 'Only package class',
                        'type'     => 'select-pkg_class',
                        'multiple' => 1,
                      },
    'discountnum' => { 'label'    => 'Discount',
                       'type'     => 'select-table', #we don't handle the select-discount create a discount case
                       'table'    => 'discount',
                       #(well, since 2013 it winds up calling select-discount
                       # anyway (but not tr-select-discount)
                       #'name_col' => 'description', #well, method
                       #'order_by' => 'ORDER BY discountnum', #requied because name_col is a method
                       'disable_empty' => 1,
                       'hashref'  => { 'disabled' => '',
                                       'months'   => { op=>'!=', value=>'0' },
                                     },
                       'disable_custom_discount' => 1,
                     },
    'once_percust' => { 'label' => 'Only discount one package per customer',
                        'type'  => 'checkbox',
                        'value' => 'Y',
                      },
  );
}

#lots of false laziness with referral_pkg_discount
#but also lots of doing it differently...and better???
sub do_action {
  my( $self, $object, $cust_event ) = @_;

  my $cust_main = $self->cust_main($object);
  my %if_pkgpart = map { $_=>1 } split(/\s*,\s*/, $self->option('if_pkgpart') );
  my %if_pkg_class = map { $_=>1 } split(/\s*,\s*/, $self->option('if_pkg_class') );

  my $allpkgs = (keys %if_pkgpart) ? 0 : 1;

  my @cust_pkg = ();
  if ( $object->table eq 'cust_pkg' ) {

    return 'Package is suspended' if $object->susp;
    return 'Package not selected'
      if ! $allpkgs && ! $if_pkgpart{ $object->pkgpart };
    return 'Package not of selected class'
      if keys %if_pkg_class
      && ! $if_pkg_class{ $object->part_pkg->classnum };
    return 'Package frequency not monthly or a multiple'
      if $object->part_pkg->freq !~ /^\d+$/;

    @cust_pkg = ( $object );

  } else {

    @cust_pkg = grep {
         ( $allpkgs || $if_pkgpart{ $_->pkgpart } ) 
      && ( ! keys %if_pkg_class || $if_pkg_class{ $_->part_pkg->classnum } )
      && $_->part_pkg->freq
      #remove after fixing discount bug with non-monthly pkgs
      && ( $_->part_pkg->freq =~ /^\d+$/)
    }
      $cust_main->unsuspended_pkgs;

    return 'No qualifying packages' unless @cust_pkg;

  }

  my $gotit = 0;
  foreach my $cust_pkg (@cust_pkg) {

    my @cust_pkg_discount = $cust_pkg->cust_pkg_discount_active;

    #our logic here only makes sense insomuch as you can't have multiple discounts
    die "Unexpected multiple discounts, contact developers"
      if scalar(@cust_pkg_discount) > 1;

    my @my_cust_pkg_discount =
      grep { $_->discountnum == $self->option('discountnum') } @cust_pkg_discount;

    if ( @my_cust_pkg_discount ) { #reset the existing one instead

      $gotit = 1;

      #it's already got this discount and discount never expires--great, move on
      unless ( $cust_pkg_discount[0]->discount->months ) {
        if ( $self->option('once_percust') ) {
          last;
        } else {
          next;
        }
      };
	
      #reset the discount
      my $error = $cust_pkg_discount[0]->decrement_months_used( $cust_pkg_discount[0]->months_used );
      die "Error extending discount: $error\n" if $error;

      last if $self->option('once_percust');

    } elsif ( @cust_pkg_discount ) {

      #can't currently discount an already discounted package,
      #but maybe we can discount a different package
      next;

    } else { #normal case, create a new one

      $gotit = 1;
      my $cust_pkg_discount = new FS::cust_pkg_discount {
        'pkgnum'      => $cust_pkg->pkgnum,
        'discountnum' => $self->option('discountnum'),
        'months_used' => 0
      };
      my $error = $cust_pkg_discount->insert;
      die "Error discounting package: $error\n" if $error;

      last if $self->option('once_percust');

    }
  }

  return $gotit ? '' : 'Discount not applied due to existing discounts';

}

1;
