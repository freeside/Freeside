package FS::svc_Torrus_Mixin;

use strict;
use vars qw($conf $system $DEBUG $me );
use List::Util qw(max);
use Date::Format qw(time2str);
use Data::Dumper;
use GD;
use GD::Graph;
use GD::Graph::mixed;
use FS::UID qw( driver_name );
use FS::Record qw( qsearch str2time_sql str2time_sql_closing concat_sql );

$DEBUG = 1;
$me = '[FS::svc_Torrus_Mixin]';

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $system = $conf->config('network_monitoring_system');
} );

=head1 NAME

FS::svc_Torrus_Mixin - Mixin class for svc_classes with a Torrus serviceid field

=head1 SYNOPSIS

package FS::svc_table;
use base qw( FS::svc_Torrus_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that contain a serviceid field linking
to the torrus srvexport / reportfields tables.

=head1 METHODS

=over 4

=item graph_png

Returns a PNG graph for this port.

The following options must be specified:

=over 4

=item start
=item end

=back

=cut

sub _format_bandwidth {
    my $self = shift;
    my $value = shift;
    my $space = shift;
    $space = ' ' if $space;

    my $suffix = '';

    warn "$me _format_bandwidth $value" if $DEBUG > 1;

    if ( $value >= 1000 && $value < 1000000 ) {
        $value = ($value/1000);
        $suffix = $space. "k";
    }
    elsif( $value >= 1000000 && $value < 1000000000 ) {
        $value = ($value/1000/1000);
        $suffix = $space . "M";
    }
    elsif( $value >= 1000000000 && $value < 1000000000000 ) {
        $value = ($value/1000/1000/1000);
        $suffix = $space . "G";
    }
    # and hopefully we don't have folks doing Tbps on a single port :)

    $value = sprintf("%6.2f$suffix",$value) if $value >= 0;

    $value;
}

sub _percentile {
  my $self = shift;
  my @values = sort { $a <=> $b } @{$_[0]};
  $values[ int(.95 * $#values) ];
}

sub graph_png {
  my($self, %opt) = @_;
  my $serviceid = $self->serviceid;

  return '' unless $serviceid && $system eq 'Torrus_Internal'; #empty/error png?

  my $start = -1;
  my $end = -1;
  my $now = time;

  $start = $opt{start} if $opt{start};
  $end = $opt{end} if $opt{end};

        $end = $now if $end > $now;

  return 'Invalid date range' if ($start < 0 || $start >= $end 
      || $end <= $start || $end < 0 || $end > $now || $start > $now
      || $end-$start > 86400*366 );

  my $_date = concat_sql([ 'srv_date', "' '", 'srv_time' ]);
  $_date = "CAST( $_date AS TIMESTAMP )" if driver_name =~ /^Pg/i;
  $_date = str2time_sql. $_date.  str2time_sql_closing;

  my $serviceid_sql = "('${serviceid}_IN','${serviceid}_OUT')";

  local($FS::Record::nowarn_classload) = 1;
  my @records = qsearch({
    'table'     => 'srvexport',
    'select'    => "*, $_date as _date",
    'extra_sql' => "where serviceid in $serviceid_sql
                      and $_date >= $start
                      and $_date <= $end",
    'order_by'  => "order by $_date asc",
  });

  if ( ! scalar(@records) ) {
    warn "$me no records returned for $serviceid\n";
    return ''; #should actually return a blank png (or, even better, the
               # error message in the image)
  }

  warn "$me ". scalar(@records). " records returned for $serviceid\n"
    if $DEBUG;

  # assume data in DB is correct,
  # assume always _IN and _OUT pair, assume intvl = 300

  my @times;
  my @in;
  my @out;
  foreach my $rec ( @records ) {
      push @times, $rec->_date 
          unless grep { $_ eq $rec->_date } @times;
      push @in, $rec->value*8 if $rec->serviceid =~ /_IN$/;
      push @out, $rec->value*8 if $rec->serviceid =~ /_OUT$/;
  }

  my $timediff = $times[-1] - $times[0]; # they're sorted ascending

  my $y_min = 999999999999; # ~1Tbps
  my $y_max = 0;
  my $in_sum = 0;
  my $out_sum = 0;
  my $in_min = 999999999999;
  my $in_max = 0;
  my $out_min = 999999999999;
  my $out_max = 0;
  foreach my $in ( @in ) {
      $y_max = $in if $in > $y_max;
      $y_min = $in if $in < $y_min;
      $in_sum += $in;
      $in_max = $in if $in > $in_max;
      $in_min = $in if $in < $in_min;
  }
  foreach my $out ( @out ) {
      $y_max = $out if $out > $y_max;
      $y_min = $out if $out < $y_min;
      $out_sum += $out;
      $out_max = $out if $out > $out_max;
      $out_min = $out if $out < $out_min;
  }
  my $bwdiff = $y_max - $y_min;
  $in_min = $self->_format_bandwidth($in_min);
  $out_min = $self->_format_bandwidth($out_min);
  $in_max = $self->_format_bandwidth($in_max);
  $out_max = $self->_format_bandwidth($out_max);
  my $in_curr = $self->_format_bandwidth($in[-1]);
  my $out_curr = $self->_format_bandwidth($out[-1]);
  my $numsamples = scalar(@records)/2;
  my $in_avg = $self->_format_bandwidth($in_sum/$numsamples);
  my $out_avg = $self->_format_bandwidth($out_sum/$numsamples);

  my $percentile = max( $self->_percentile(\@in), $self->_percentile(\@out) );
  my @percentile = map $percentile, @in;
  $percentile = $self->_format_bandwidth($percentile); #for below

  warn "$me timediff=$timediff bwdiff=$bwdiff start=$start end=$end ".
       "in_min=$in_min out_min=$out_min in_max=$in_max ".
       "out_max=$out_max in_avg=$in_avg out_avg=$out_avg ".
       "percentile=$percentile ".
       " # records = " . scalar(@records) . "\n\ntimes:\n".
       Dumper(@times) . "\n\nin:\n" . Dumper(@in) . "\n\nout:\n". Dumper(@out)
    if $DEBUG > 1;

  my @data = ( \@times, \@in, \@out, \@percentile );

  
  # hardcoded size, colour, etc.

  #don't change width/height other than through here; breaks legend otherwise
  my $width = 600;
  my $height = 360;

  my $graph = new GD::Graph::mixed($width,$height);  
  $graph->set(
    types => ['area','lines','lines'],
    dclrs => ['green','blue','red',],
    x_label => '   ',
    x_tick_number => 'auto',
    x_number_format => sub {
        my $value = shift;
        if ( $timediff < 86401 ) { # one day
            $value = time2str("%a %H:%M",$value) 
        } elsif ( $timediff < 86401*7 ) { # one week
            $value = time2str("%d",$value) 
        } elsif ( $timediff < 86401*30 ) { # one month
            $value = time2str("Week %U",$value) 
        } elsif ( $timediff < 86401*366 ) { # one year
            $value = time2str("%b",$value)
        }
        $value;
    },
    y_number_format => sub {
        my $value = shift;
        $self->_format_bandwidth($value,1);
    },
        y_tick_number => 'auto',
    y_label => 'bps',
    legend_placement => 'BR',
        lg_cols => 1,
    title => $self->serviceid,
  ) or return "can't create graph: ".$graph->error;
  
  $graph->set_text_clr('black') 
    or return "can't set text colour: ".$graph->error;
  $graph->set_legend(('In','Out','95th')) 
    or return "can't set legend: ".$graph->error;
  $graph->set_title_font(['verdana', 'arial', gdGiantFont], 16)
        or return "can't set title font: ".$graph->error;
  $graph->set_legend_font(['verdana', 'arial', gdMediumBoldFont], 12)
        or return "can't set legend font: ".$graph->error;
  $graph->set_x_axis_font(['verdana', 'arial', gdMediumBoldFont], 12)
        or return "can't set font: ".$graph->error;
  $graph->set_y_axis_font(['verdana', 'arial', gdMediumBoldFont], 12)
        or return "can't set font: ".$graph->error;
  $graph->set_y_label_font(['verdana', 'arial', gdMediumBoldFont], 12)
        or return "can't set font: ".$graph->error;

  my $gd = $graph->plot(\@data);
  return "graph error: ".$graph->error unless($gd);

  my $black = $gd->colorAllocate(0,0,0);       
  $gd->string(gdMediumBoldFont,50,$height-55,
    "Current:$in_curr   Average:$in_avg   Maximum:$in_max   Minimum:$in_min",$black);
  $gd->string(gdMediumBoldFont,50,$height-35,
    "Current:$out_curr   Average:$out_avg   Maximum:$out_max   Minimum:$out_min",$black);
  $gd->string(gdMediumBoldFont,50,$height-15,
    "95th percentile:$percentile", $black);

  return $gd->png;
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_port>, L<FS::svc_broadband>, Torrus documentation

=cut

1;


