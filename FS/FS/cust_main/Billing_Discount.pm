package FS::cust_main::Billing_Discount;

use strict;
use vars qw( $DEBUG $me );
use FS::Record qw( qsearch ); #qsearchs );
use FS::cust_pkg;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Billing_Discount]';

=head1 NAME

FS::cust_main::Billing_Discount - Billing discount mixin for cust_main

=head1 SYNOPSIS

=head1 DESCRIPTION

These methods are available on FS::cust_main objects.

=head1 METHODS

=over 4

=item _discount_pkg_and_bill

=cut

sub _discount_pkgs_and_bill {
  my $self = shift;

  my @cust_bill = $self->cust_bill;
  my $cust_bill = pop @cust_bill;
  return () unless $cust_bill && $cust_bill->owed;

  my @where = ();
  push @where, "cust_bill_pkg.invnum = ". $cust_bill->invnum;
  push @where, "cust_bill_pkg.pkgpart_override IS NULL";
  push @where, "part_pkg.freq = '1'";
  push @where, "(cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0)";
  push @where, "(cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0)";
  push @where, "0<(SELECT count(*) FROM part_pkg_discount
                  WHERE part_pkg.pkgpart = part_pkg_discount.pkgpart)";
  push @where,
    "0=(SELECT count(*) FROM cust_bill_pkg_discount
         WHERE cust_bill_pkg.billpkgnum = cust_bill_pkg_discount.billpkgnum)";

  my $extra_sql = 'WHERE '. join(' AND ', @where);

  my @cust_pkg = 
    qsearch({
      'table' => 'cust_pkg',
      'select' => "DISTINCT cust_pkg.*",
      'addl_from' => 'JOIN cust_bill_pkg USING(pkgnum) '.
                     'JOIN part_pkg USING(pkgpart)',
      'hashref' => {},
      'extra_sql' => $extra_sql,
    }); 

  ($cust_bill, @cust_pkg);
}

=item _discountable_pkgs_at_term

=cut

#this isn't even a method
sub _discountable_pkgs_at_term {
  my ($term, @pkgs) = @_;
  my $part_pkg = new FS::part_pkg { freq => $term - 1 };
  grep { ( !$_->adjourn || $_->adjourn > $part_pkg->add_freq($_->bill) ) && 
         ( !$_->expire  || $_->expire  > $part_pkg->add_freq($_->bill) )
       }
    @pkgs;
}

=item discount_terms

Returns a list of lengths for term discounts

=cut

sub discount_terms {
  my $self = shift;

  my %terms = ();

  my @discount_pkgs = $self->_discount_pkgs_and_bill;
  shift @discount_pkgs; #discard bill;
  
  map { $terms{$_->months} = 1 }
    grep { $_->months && $_->months > 1 }
    map { $_->discount }
    map { $_->part_pkg->part_pkg_discount }
    @discount_pkgs;

  return sort { $a <=> $b } keys %terms;

}

=item discount_term_values MONTHS

Returns a list with credit, dollar amount saved, and total bill acheived
by prepaying the most recent invoice for MONTHS.

=cut

sub discount_term_values {
  my $self = shift;
  my $term = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me discount_term_values called with $term\n" if $DEBUG;

  my %result = ();

  my @packages = $self->_discount_pkgs_and_bill;
  my $cust_bill = shift(@packages);
  @packages = _discountable_pkgs_at_term( $term, @packages );
  return () unless scalar(@packages);

  $_->bill($_->last_bill) foreach @packages;
  my @final = map { new FS::cust_pkg { $_->hash } } @packages;

  my %options = (
                  'recurring_only' => 1,
                  'no_usage_reset' => 1,
                  'no_commit'      => 1,
                );

  my %params =  (
                  'return_bill'    => [],
                  'pkg_list'       => \@packages,
                  'time'           => $cust_bill->_date,
                );

  my $error = $self->bill(%options, %params);
  die $error if $error; # XXX think about this a bit more

  my $credit = 0;
  $credit += $_->charged foreach @{$params{return_bill}};
  $credit = sprintf('%.2f', $credit);
  warn "$me discount_term_values $term credit: $credit\n" if $DEBUG;

  %params =  (
               'return_bill'    => [],
               'pkg_list'       => \@packages,
               'time'           => $packages[0]->part_pkg->add_freq($cust_bill->_date)
             );

  $error = $self->bill(%options, %params);
  die $error if $error; # XXX think about this a bit more

  my $next = 0;
  $next += $_->charged foreach @{$params{return_bill}};
  warn "$me discount_term_values $term next: $next\n" if $DEBUG;
  
  %params =  ( 
               'return_bill'    => [],
               'pkg_list'       => \@final,
               'time'           => $cust_bill->_date,
               'freq_override'  => $term,
             );

  $error = $self->bill(%options, %params);
  die $error if $error; # XXX think about this a bit more

  my $final = $self->balance - $credit;
  $final += $_->charged foreach @{$params{return_bill}};
  $final = sprintf('%.2f', $final);
  warn "$me discount_term_values $term final: $final\n" if $DEBUG;

  my $savings = sprintf('%.2f', $self->balance + ($term - 1) * $next - $final);

  ( $credit, $savings, $final );

}

sub discount_terms_hash {
  my $self = shift;

  my %result = ();
  my @terms = $self->discount_terms;
  foreach my $term (@terms) {
    my @result = $self->discount_term_values($term);
    $result{$term} = [ @result ] if scalar(@result);
  }

  return %result;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_main::Billing>

=cut

1;
