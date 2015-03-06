package FS::Report::Table::Daily;

use strict;
use base 'FS::Report::Table';
use DateTime;
use FS::Conf;

=head1 NAME

FS::Report::Table::Daily - Tables of report data, indexed daily

=head1 SYNOPSIS

  use FS::Report::Table::Daily;

  my $report = new FS::Report::Table::Daily (
    'items' => [ 'invoiced', 'netsales', 'credits', 'receipts', ],
    'start_month' => 4,
    'start_year'  => 2000,
    'end_month'   => 4,
    'end_year'    => 2020,
    'start_day'   => 2,
    'end_day'     => 27,
    #opt
    'agentnum'    => 54
    'cust_classnum' => [ 1,2,4 ],
    'params'      => [ [ 'paramsfor', 'item_one' ], [ 'item', 'two' ] ], # ...
    'remove_empty' => 1, #collapse empty rows, default 0
    'item_labels' => [ ], #useful with remove_empty
  );

  my $data = $report->data;

=head1 METHODS

=over 4

=item data

Returns a hashref of data (!! describe)

=cut

sub data {
  my $self = shift;

  my $sday = $self->{'start_day'};
  my $smonth = $self->{'start_month'};
  my $syear = $self->{'start_year'} + 1900; # temporary kludge
  my $eday = $self->{'end_day'};
  my $emonth = $self->{'end_month'};
  my $eyear = $self->{'end_year'} + 1900;
  my $agentnum = $self->{'agentnum'};
  my $cust_classnum = $self->{'cust_classnum'} || [];
  $cust_classnum = [ $cust_classnum ] if !ref($cust_classnum);

  #these need to get generalized, sheesh
  my %data = (
    # rows (time intervals)
    speriod   => [], # start timestamps
    eperiod   => [], # end timestamps
    label     => [], # date labels
    data      => [], # arrayrefs of column values

    # columns (observables + query parameters)
    items         => $self->{'items'},
    item_labels   => $self->{'item_labels'} || $self->{'items'},
    colors        => $self->{'colors'}, # no default?
    links         => $self->{'links'} || [],
  );

  my $sdate = DateTime->new(
                day => $sday,
                month => $smonth,
                year => $syear,
                time_zone => 'local'
              );
  my $edate = DateTime->new(
                day => $eday,
                month => $emonth,
                year => $eyear,
                time_zone => 'local'
              )->add(days => 1); # include all of the end day

  my $conf = FS::Conf->new;
  my $date_format = $conf->config('date_format') || '%d/%m/%Y';

  while ( $sdate < $edate ) {
    push @{$data{label}}, $sdate->strftime($date_format);

    my $speriod = $sdate->epoch;
    $sdate->add(days => 1);
    my $eperiod = $sdate->epoch;;

    push @{$data{speriod}}, $speriod;
    push @{$data{eperiod}}, $eperiod;

    my $col = 0;
    my @items = @{$self->{'items'}};
    my $i;
    for ( $i = 0; $i < scalar(@items); $i++ ) {
	  my $item = $items[$i];
	  my @param = $self->{'params'} ? @{ $self->{'params'}[$col] }: ();
          push @param, 'cust_classnum' => $cust_classnum if @$cust_classnum;
	  my $value = $self->$item($speriod, $eperiod, $agentnum, @param);
	  push @{$data{data}->[$col++]}, $value;
    }
  }

  $data{'items'}       = $self->{'items'};
  $data{'item_labels'} = $self->{'item_labels'} || $self->{'items'};
  $data{'colors'}      = $self->{'colors'};
  $data{'links'}       = $self->{'links'} || [];

  if ( $self->{'remove_empty'} ) {

    my $col = 0;
    #these need to get generalized, sheesh
    my @newitems = ();
    my @newlabels = ();
    my @newdata = ();
    my @newcolors = ();
    my @newlinks = ();
    foreach my $item ( @{$self->{'items'}} ) {

      if ( grep { $_ != 0 } @{$data{'data'}->[$col]} ) {
        push @newitems,  $data{'items'}->[$col];
        push @newlabels, $data{'item_labels'}->[$col];
        push @newdata,   $data{'data'}->[$col];
        push @newcolors, $data{'colors'}->[$col];
        push @newlinks,  $data{'links'}->[$col];
      }

      $col++;
    }

    $data{'items'}       = \@newitems;
    $data{'item_labels'} = \@newlabels;
    $data{'data'}        = \@newdata;
    $data{'colors'}      = \@newcolors;
    $data{'links'}       = \@newlinks;

  }

  \%data;

}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

1;
