package FS::detail_format::sum_count;

use strict;
use vars qw( $DEBUG );
use base qw(FS::detail_format);
use FS::Record qw(qsearchs);
use FS::cust_svc;
use FS::svc_Common; # for label

$DEBUG = 0;

sub name { 'Number of calls, one line per service' };

sub header_detail {
  my $self = shift;
  if ( $self->{inbound} ) {
    'Destination,Messages,Price'
  }
  else {
    'Source,Messages,Price'
  }
}

sub append {
  my $self = shift;
  my $svcnums = ($self->{svcnums} ||= {});
  foreach my $cdr (@_) {
    my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
    my $svcnum = $object->svcnum; # yes, $object->svcnum.

    my $subtotal = ($svcnums->{$svcnum} ||=
      { count => 0, duration => 0, amount => 0 });
    $subtotal->{count}++;
    $subtotal->{amount} += $object->rated_price;
  }
}

sub finish {
  my $self = shift;
  my $svcnums = $self->{svcnums};
  my $buffer = $self->{buffer};
  foreach my $svcnum (keys %$svcnums) {

    my $subtotal = $svcnums->{$svcnum};
    next if $subtotal->{amount} < 0.01;

    my $cust_svc = qsearchs('cust_svc', { svcnum => $svcnum })
      or die "svcnum #$svcnum not found";
    my $phonenum = $cust_svc->svc_x->label;
    warn "processing $phonenum\n" if $DEBUG;

    $self->csv->combine(
      $phonenum,
      $subtotal->{count},
      $self->money_char . sprintf('%.02f',$subtotal->{amount}),
    );

    warn "adding detail: ".$self->csv->string."\n" if $DEBUG;

    push @$buffer, FS::cust_bill_pkg_detail->new({
        amount      => $subtotal->{amount},
        format      => 'C',
        classnum    => '', #ignored in this format
        duration    => '',
        phonenum    => $phonenum,
        accountcode => '', #ignored in this format
        startdate   => '', #could use the earliest startdate in the bunch?
        regionname  => '', #no, we're using prefix instead
        detail      => $self->csv->string,
    });
  } #foreach $svcnum

  # supposedly the compiler is smart enough to do this in place
  @$buffer = sort { $a->{Hash}->{phonenum} cmp $b->{Hash}->{phonenum} } 
              @$buffer;
}

1;
