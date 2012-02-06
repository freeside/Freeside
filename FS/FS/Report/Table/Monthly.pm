package FS::Report::Table::Monthly;

use strict;
use vars qw( @ISA );
use FS::UID qw(dbh);
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
  local $FS::UID::AutoCommit = 0;
  my $self = shift;

  my $smonth  = $self->{'start_month'};
  my $syear   = $self->{'start_year'};
  my $emonth  = $self->{'end_month'};
  my $eyear   = $self->{'end_year'};
  # how far to extrapolate into the future
  my $pmonth  = $self->{'project_month'};
  my $pyear   = $self->{'project_year'};

  # sanity checks
  if ( $eyear < $syear or
      ($eyear == $syear and $emonth < $smonth) ) {
    return { error => 'Start month must be before end month' };
  }

  my $agentnum = $self->{'agentnum'};

  if ( $pyear > $eyear or
      ($pyear == $eyear and $pmonth > $emonth) ) {

    # create the entire projection set first to avoid timing problems

    $self->init_projection if $pmonth;

    my $thisyear = $eyear;
    my $thismonth = $emonth;
    while ( $thisyear < $pyear || 
      ( $thisyear == $pyear and $thismonth <= $pmonth )
    ) {
      my $speriod = timelocal(0,0,0,1,$thismonth-1,$thisyear);
      $thismonth++;
      if ( $thismonth == 13 ) { $thisyear++; $thismonth = 1; }
      my $eperiod = timelocal(0,0,0,1,$thismonth-1,$thisyear);

      $self->extend_projection($speriod, $eperiod);
    }
  }

  my %data;

  my $max_year = $pyear || $eyear;
  my $max_month = $pmonth || $emonth;

  my $projecting = 0; # are we currently projecting?

  while ( $syear < $max_year
     || ( $syear == $max_year && $smonth < $max_month+1 ) ) {

    if ( $self->{'doublemonths'} ) {
      my($firstLabel,$secondLabel) = @{$self->{'doublemonths'}};
      push @{$data{label}}, "$smonth/$syear $firstLabel";
      push @{$data{label}}, "$smonth/$syear $secondLabel";
    }
    else {
      push @{$data{label}}, "$smonth/$syear";
    }

    if ( $syear > $eyear || ( $syear == $eyear && $smonth >= $emonth + 1 ) ) {
      # start getting data from the projection
      $projecting = 1;
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
        push @param, 'project', $projecting;
        my $value = $self->$item($speriod, $eperiod, $agentnum, @param);
        push @{$data{data}->[$col]}, $value;
        $item = $items[$i+1]; 
        @param = $self->{'params'} ? @{ $self->{'params'}[++$i] }: ();
        push @param, 'project', $projecting;
        $value = $self->$item($speriod, $eperiod, $agentnum, @param);
        push @{$data{data}->[$col++]}, $value;
      }
      else {
        my $item = $items[$i];
        my @param = $self->{'params'} ? @{ $self->{'params'}[$col] }: ();
        push @param, 'project', $projecting;
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
  # clean up after ourselves
  #dbh->rollback;
  # leave in until development is finished, for diagnostics
  dbh->commit;

  \%data;
}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

1;

