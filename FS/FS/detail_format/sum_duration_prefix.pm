package FS::detail_format::sum_duration_prefix;

use strict;
use vars qw( $DEBUG );
use base qw(FS::detail_format);
use List::Util qw(sum);

$DEBUG = 0;

my $me = '[sum_duration_prefix]';

sub name { 'Summary, one line per destination prefix' };
# and also..."rate group"?  what do you call the interstate/intrastate rate 
# distinction?

sub header_detail {
  'Destination NPA-NXX,Interstate Calls,Duration,Intrastate Calls,Duration,Price';
}

my $prefix_length = 6;
# possibly should use rate_prefix for this, but interstate/intrastate uses 
# them in a strange way and we are following along

sub append {
  my $self = shift;
  my $prefixes = ($self->{prefixes} ||= {});
  foreach my $cdr (@_) {
    my $phonenum = $self->{inbound} ? $cdr->src : $cdr->dst;
    $phonenum =~ /^(\d{$prefix_length})/;
    my $prefix = $1 || 'other';
    warn "$me appending ".$cdr->dst." to $prefix\n" if $DEBUG;

    # XXX hardcoded ratenames, not the worst of evils
    $prefixes->{$prefix} ||= { 
      Interstate => { count => 0, duration => 0, amount => 0 }, 
      Intrastate => { count => 0, duration => 0, amount => 0 }, 
    };
    my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
    # XXX using $cdr's rated_ratename instead of $object because 
    # cdr_termination doesn't have one...
    # but interstate-ness should be symmetric, yes?  if A places an
    # interstate call to B, then B receives an interstate call from A.
    my $subtotal = $prefixes->{$prefix}{$cdr->rated_ratename}
      or next; 
      # silently skip calls that are neither interstate nor intrastate
    #or die "unknown rated_ratename '" .$cdr->rated_ratename.
    #         "' in CDR #".$cdr->acctid."\n";
    $subtotal->{count}++;
    $subtotal->{duration} += $object->rated_seconds;
    $subtotal->{amount} += $object->rated_price
      if $object->freesidestatus ne 'no-charge';
  }
}

sub finish {
  my $self = shift;
  my $prefixes = $self->{prefixes};
  foreach my $prefix (sort { $a cmp $b } keys %$prefixes) {

    warn "processing $prefix\n" if $DEBUG;

    my $ratenames = $prefixes->{$prefix};
    my @subtotals = ($ratenames->{'Interstate'}, $ratenames->{'Intrastate'});
    my $total_amount   = sum( map { $_->{'amount'} } @subtotals );
    my $total_duration = sum( map { $_->{'duration'} } @subtotals );
    $prefix =~ s/(...)(...)/$1 - $2/;

    next if $total_amount < 0.01;

    $self->csv->combine(
      $prefix,
      map({ 
          $_->{count},
          (int($_->{duration}/60) . ' min'),
        } @subtotals ),
      $self->money_char . sprintf('%.02f',$total_amount),
    );

    warn "adding detail: ".$self->csv->string."\n" if $DEBUG;

    push @{ $self->{buffer} }, FS::cust_bill_pkg_detail->new({
        amount      => $total_amount,
        format      => 'C',
        classnum    => '', #ignored in this format
        duration    => $total_duration,
        phonenum    => '', # not divided up per service
        accountcode => '', #ignored in this format
        startdate   => '', #could use the earliest startdate in the bunch?
        regionname  => '', #no, we're using prefix instead
        detail      => $self->csv->string,
    });
  } #foreach $prefix
}

1;
