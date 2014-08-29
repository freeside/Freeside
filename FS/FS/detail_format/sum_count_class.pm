package FS::detail_format::sum_count_class;

use strict;
use vars qw( $DEBUG );
use base qw(FS::detail_format);
use FS::Record qw(qsearchs);
use FS::cust_svc;
use FS::svc_Common; # for label

$DEBUG = 0;

sub name { 'Summary, one line per service and usage class' };

sub header_detail {
  my $self = shift;
  if ( $self->{inbound} ) {
    'Destination,Charge Class,Quantity,Price'
  }
  else {
    'Source,Charge Class,Quantity,Price'
  }
}

sub append {
  my $self = shift;
  my $svcnums = ($self->{svcnums} ||= {});
  my $acctids = $self->{acctids} ||= {};
  foreach my $cdr (@_) {
    my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
    my $svcnum = $object->svcnum; # yes, $object->svcnum.

    my $subtotal = ($svcnums->{$svcnum}->{$cdr->rated_classnum} ||=
      { count => 0, duration => 0, amount => 0 });
    $subtotal->{count}++;
    $subtotal->{duration} += $object->rated_seconds;
    $subtotal->{amount} += $object->rated_price
      if $object->freesidestatus ne 'no-charge';

    my $these_acctids = $acctids->{$cdr->rated_classnum} ||= [];
    push @$these_acctids, $cdr->acctid;
  }
}

sub finish {
  my $self = shift;
  my $svcnums = $self->{svcnums};
  my $buffer = $self->{buffer};
  foreach my $svcnum (keys %$svcnums) {

    my $classnums = $svcnums->{$svcnum};

    my $cust_svc = qsearchs('cust_svc', { svcnum => $svcnum })
      or die "svcnum #$svcnum not found";
    my $phonenum = $cust_svc->svc_x->label;
    warn "processing $phonenum\n" if $DEBUG;

    foreach my $classnum (keys %$classnums) {
      my $subtotal = $classnums->{$classnum};
      next if $subtotal->{amount} < 0.01;
      my $classname = ($classnum ?
                        FS::usage_class->by_key($classnum)->classname :
                        '');
      $self->csv->combine(
        $phonenum,
        $classname,
        $subtotal->{count},
        $self->money_char . sprintf('%.02f',$subtotal->{amount}),
      );

      warn "adding detail: ".$self->csv->string."\n" if $DEBUG;

      push @$buffer, FS::cust_bill_pkg_detail->new({
          amount      => $subtotal->{amount},
          format      => 'C',
          classnum    => $classnum,
          duration    => $subtotal->{duration},
          phonenum    => $phonenum,
          accountcode => '', #ignored in this format
          startdate   => '', #could use the earliest startdate in the bunch?
          regionname  => '',
          detail      => $self->csv->string,
          acctid      => $self->{acctids}->{$classnum},
      });
    } #foreach $classnum
  } #foreach $svcnum

  # supposedly the compiler is smart enough to do this in place
  @$buffer = sort { $a->{Hash}->{phonenum} cmp $b->{Hash}->{phonenum} or
                    $a->{Hash}->{classnum} <=> $b->{Hash}->{classnum} } 
              @$buffer;
}

1;
