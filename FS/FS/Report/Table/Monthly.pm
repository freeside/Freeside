package FS::Report::Table::Monthly;

use strict;
use vars qw( @ISA );
use FS::Report::Table;
use Time::Local qw( timelocal );

@ISA = qw( FS::Report::Table );

=head1 NAME

FS::Report::Table::Monthly - Tables of report data, indexed monthly

=head1 SYNOPSIS

  use FS::Report::Table::Monthly;

  my $report = new FS::Report::Table::Monthly (
    'items' => [ 'invoiced', 'netsales', 'credits', 'receipts', ],
    'start_month' => 4,
    'start_year'  => 2000,
    'end_month'   => 4,
    'end_year'    => 2020,
    #opt
    'agentnum'    => 54
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

  my $smonth = $self->{'start_month'};
  my $syear = $self->{'start_year'};
  my $emonth = $self->{'end_month'};
  my $eyear = $self->{'end_year'};
  my $agentnum = $self->{'agentnum'};

  my %data;

  while ( $syear < $eyear || ( $syear == $eyear && $smonth < $emonth+1 ) ) {

    if ( $self->{'doublemonths'} ) {
	my($firstLabel,$secondLabel) = @{$self->{'doublemonths'}};
	push @{$data{label}}, "$smonth/$syear $firstLabel";
	push @{$data{label}}, "$smonth/$syear $secondLabel";
    }
    else {
	push @{$data{label}}, "$smonth/$syear";
    }

    my $speriod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{speriod}}, $speriod;
    if ( ++$smonth == 13 ) { $syear++; $smonth=1; }
    my $eperiod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{eperiod}}, $eperiod;
  
    my $col = 0;
    my @items = @{$self->{'items'}};
    my $i;
    for ( $i = 0; $i < scalar(@items); $i++ ) {
      if ( $self->{'doublemonths'} ) {
	  my $item = $items[$i]; 
	  my @param = $self->{'params'} ? @{ $self->{'params'}[$i] }: ();
	  my $value = $self->$item($speriod, $eperiod, $agentnum, @param);
	  push @{$data{data}->[$col]}, $value;
	  $item = $items[$i+1]; 
	  @param = $self->{'params'} ? @{ $self->{'params'}[++$i] }: ();
	  $value = $self->$item($speriod, $eperiod, $agentnum, @param);
	  push @{$data{data}->[$col++]}, $value;
      }
      else {
	  my $item = $items[$i];
	  my @param = $self->{'params'} ? @{ $self->{'params'}[$col] }: ();
	  my $value = $self->$item($speriod, $eperiod, $agentnum, @param);
	  push @{$data{data}->[$col++]}, $value;
      }
    }

  }

  #these need to get generalized, sheesh
  $data{'items'}       = $self->{'items'};
  $data{'item_labels'} = $self->{'item_labels'} || $self->{'items'};
  $data{'colors'}      = $self->{'colors'};
  $data{'links'}       = $self->{'links'} || [];

  if ( $self->{'remove_empty'} ) {

    my $col = 0;
    #these need to get generalized, sheesh
    #(though we now return a list of item indices that are present in the 
    #output, so the front-end code could do this)
    my @newitems = ();
    my @newlabels = ();
    my @newdata = ();
    my @newcolors = ();
    my @newlinks = ();
    my @indices = ();
    foreach my $item ( @{$self->{'items'}} ) {

      if ( grep { $_ != 0 } @{$data{'data'}->[$col]} ) {
        push @newitems,  $data{'items'}->[$col];
        push @newlabels, $data{'item_labels'}->[$col];
        push @newdata,   $data{'data'}->[$col];
        push @newcolors, $data{'colors'}->[$col];
        push @newlinks,  $data{'links'}->[$col];
        push @indices,   $col;
      }

      $col++;
    }

    $data{'items'}       = \@newitems;
    $data{'item_labels'} = \@newlabels;
    $data{'data'}        = \@newdata;
    $data{'colors'}      = \@newcolors;
    $data{'links'}       = \@newlinks;
    $data{'indices'}     = \@indices;

  }

  \%data;
}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

1;

