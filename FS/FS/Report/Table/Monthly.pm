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
    'refnum'      => 54
    'params'      => [ [ 'paramsfor', 'item_one' ], [ 'item', 'two' ] ], # ...
    'remove_empty' => 1, #collapse empty rows, default 0
    'item_labels' => [ ], #useful with remove_empty
  );

  my $data = $report->data;

=head1 PARAMETERS

=head2 TIME PERIOD

C<start_month>, C<start_year>, C<end_month>, and C<end_year> specify the date
range to be included in the report.  The start and end months are included.
Each month's values are summed from midnight on the first of the month to 
23:59:59 on the last day of the month.

=head2 REPORT ITEMS

=over 4

=item items: An arrayref of observables to calculate for each month.  See 
L<FS::Report::Table> for a list of observables and their parameters.

=item params: An arrayref, parallel to C<items>, of arrayrefs of parameters
(in paired name/value form) to be passed to the observables.

=item cross_params: Cross-product parameters.  This must be an arrayref of 
arrayrefs of parameters (paired name/value form).  This creates an additional 
"axis" (orthogonal to the time and C<items> axes) in which the item is 
calculated once with each set of parameters in C<cross_params>.  These 
parameters are merged with those in C<params>.  Instead of being nested two
levels, C<data> will be nested three levels, with the third level 
corresponding to this arrayref.

=back

=head2 FILTERING

=over 4

=item agentnum: Limit to customers with this agent.

=item refnum: Limit to customers with this advertising source.

=item remove_empty: Set this to a true value to hide rows that contain 
only zeroes.  The C<indices> array in the returned data will list the item
indices that are actually present in the output so that you know what they
are.  Ignored if C<cross_params> is in effect.

=back

=head2 PASS-THROUGH

C<item_labels>, C<colors>, and C<links> may be specified as arrayrefs
parallel to C<items>.  Those values will be returned in C<data>, with any
hidden rows (due to C<remove_empty>) filtered out, which is the only 
reason to do this.  Now that we have C<indices> it's probably better to 
use that.

=head1 RETURNED DATA

The C<data> method runs the report and returns a hashref of the following:

=over 4

=item label

Month labels, in MM/YYYY format.

=item speriod, eperiod

Absolute start and end times of each month, in unix time format.

=item items

The values passed in as C<items>, with any suppressed rows deleted.

=item indices

The indices of items in the input C<items> list that appear in the result
set.  Useful for figuring out what they are when C<remove_empty> has deleted 
some items.

=item item_labels, colors, links - see PASS-THROUGH above

=item data

The actual results.  An arrayref corresponding to C<label> (the time axis),
containing arrayrefs corresponding to C<items>, containing either numbers
or, if C<cross_params> is given, arrayrefs corresponding to C<cross_params>.

=back

=cut

sub data {
  local $FS::UID::AutoCommit = 0;
  my $self = shift;

  my $smonth  = $self->{'start_month'};
  my $syear   = $self->{'start_year'};
  my $emonth  = $self->{'end_month'};
  my $eyear   = $self->{'end_year'};
  # whether to extrapolate into the future
  my $projecting = $self->{'projection'};

  # sanity checks
  if ( $eyear < $syear or
      ($eyear == $syear and $emonth < $smonth) ) {
    return { error => 'Start month must be before end month' };
  }

  my $agentnum = $self->{'agentnum'};
  my $refnum = $self->{'refnum'};

  if ( $projecting ) {

    $self->init_projection;

    my $thismonth = $smonth;
    my $thisyear  = $syear;
    while ( $thisyear < $eyear || 
      ( $thisyear == $eyear and $thismonth <= $emonth )
    ) {
      my $speriod = timelocal(0,0,0,1,$thismonth-1,$thisyear);
      $thismonth++;
      if ( $thismonth == 13 ) { $thisyear++; $thismonth = 1; }
      my $eperiod = timelocal(0,0,0,1,$thismonth-1,$thisyear);

      $self->extend_projection($speriod, $eperiod);
    }
  }

  my %data;

  my $max_year  = $eyear;
  my $max_month = $emonth;

  while ( $syear < $max_year
     || ( $syear == $max_year && $smonth < $max_month+1 ) ) {

    push @{$data{label}}, "$smonth/$syear"; # sprintf?

    my $speriod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{speriod}}, $speriod;
    if ( ++$smonth == 13 ) { $syear++; $smonth=1; }
    my $eperiod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{eperiod}}, $eperiod;

    my $col = 0;
    my @items = @{$self->{'items'}};
    my $i;

    for ( $i = 0; $i < scalar(@items); $i++ ) {
      my $item = $items[$i];
      my @param = $self->{'params'} ? @{ $self->{'params'}[$col] }: ();
      push @param, 'project', $projecting;
      push @param, 'refnum' => $refnum if $refnum;

      if ( $self->{'cross_params'} ) {
        my @xdata;
        foreach my $xparam (@{ $self->{'cross_params'} }) {
          # @$xparam is a list of additional params to merge into the list
          my $value = $self->$item($speriod, $eperiod, $agentnum,
                        @param, 
                        @$xparam);
          push @xdata, $value;
        }
        push @{$data{data}->[$col++]}, \@xdata;
      } else {
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

  if ( !$self->{'cross_params'} and $self->{'remove_empty'} ) {

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

=head1 SEE ALSO

=cut

1;

