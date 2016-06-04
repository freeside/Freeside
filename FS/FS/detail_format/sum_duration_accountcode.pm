package FS::detail_format::sum_duration_accountcode;

use strict;
use vars qw( $DEBUG );
use base qw(FS::detail_format);

$DEBUG = 0;

my $me = '[sum_duration_accountcode]';

sub name { 'Summary, one line per accountcode' };

sub header_detail {
  'Account code,Calls,Duration,Price';
}

sub append {
  my $self = shift;
  my $codes = ($self->{codes} ||= {});
  my $acctids = ($self->{acctids} ||= []);
  foreach my $cdr (@_) {
    my $accountcode = $cdr->accountcode || 'other';

    my $object = $self->{inbound} ? $cdr->cdr_termination(1) : $cdr;
    my $subtotal = $codes->{$accountcode}
               ||= { count => 0, duration => 0, amount => 0.0 };
    $subtotal->{count}++;
    $subtotal->{duration} += $object->rated_seconds;
    $subtotal->{amount} += $object->rated_price
      if $object->freesidestatus ne 'no-charge';

    push @$acctids, $cdr->acctid;
  }
}

sub finish {
  my $self = shift;
  my $codes = $self->{codes};
  foreach my $accountcode (sort { $a cmp $b } keys %$codes) {

    warn "processing $accountcode\n" if $DEBUG;

    my $subtotal = $codes->{$accountcode};

    $self->csv->combine(
      $accountcode,
      $subtotal->{count},
      sprintf('%.01f min', $subtotal->{duration}/60),
      $self->money_char . sprintf('%.02f', $subtotal->{amount})
    );

    warn "adding detail: ".$self->csv->string."\n" if $DEBUG;

    push @{ $self->{buffer} }, FS::cust_bill_pkg_detail->new({
        amount      => $subtotal->{amount},
        format      => 'C',
        classnum    => '', #ignored in this format
        duration    => $subtotal->{duration},
        phonenum    => '', # not divided up per service
        accountcode => $accountcode,
        startdate   => '',
        regionname  => '',
        detail      => $self->csv->string,
        acctid      => $self->{acctids},
    });
  } #foreach $accountcode
}

1;
