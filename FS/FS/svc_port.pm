package FS::svc_port;

use strict;
use vars qw($conf $system $DEBUG $me );
use base qw( FS::svc_Common );
use List::Util qw(max);
use Date::Format qw(time2str);
use Data::Dumper;
use GD;
use GD::Graph;
use GD::Graph::mixed;
use FS::UID qw( driver_name );
use FS::Record qw( qsearch qsearchs
                   str2time_sql str2time_sql_closing concat_sql );
use FS::cust_svc;

$DEBUG = 1;
$me = '[FS::svc_port]';

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $system = $conf->config('network_monitoring_system');
} );

=head1 NAME

FS::svc_port - Object methods for svc_port records

=head1 SYNOPSIS

  use FS::svc_port;

  $record = new FS::svc_port \%hash;
  $record = new FS::svc_port { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_port object represents a router port.  FS::table_name inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - 

=item serviceid - Torrus serviceid (in srvexport and reportfields tables)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new port.  To add the port to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_port'; }

sub table_info {
  {
    'name' => 'Port',
    #'name_plural' => 'Ports', #optional,
    #'longname_plural' => 'Ports', #optional
    'sorts' => [ 'svcnum', 'serviceid' ], # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 75,
    'cancel_weight'  => 10,
    'fields' => {
      'serviceid'         => 'Torrus serviceid',
    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#or something more complicated if necessary
sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('serviceid', $string);
}

=item label

Returns a meaningful identifier for this port

=cut

sub label {
  my $self = shift;
  $self->serviceid; #or something more complicated if necessary
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  '';
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error;

  $error = $self->SUPER::delete;
  return $error if $error;

  '';
}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  $error = $new->SUPER::replace($old);
  return $error if $error;

  '';
}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid port.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error = $self->ut_textn('serviceid'); #too lenient?
  return $error if $error;

  $self->SUPER::check;
}

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

    $value = sprintf("%.2f$suffix",$value) if $value >= 0;

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
  my @percentile = ( $percentile x scalar(@in) );
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
    "Current: $in_curr   Average: $in_avg   Maximum: $in_max   Minimum: $in_min",$black);
  $gd->string(gdMediumBoldFont,50,$height-35,
    "Current: $out_curr   Average: $out_avg   Maximum: $out_max   Minimum: $out_min",$black);
  $gd->string(gdMediumBoldFont,50,$height-15,
    "95th percentile: $percentile", $black);

  return $gd->png;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

