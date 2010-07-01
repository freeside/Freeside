% if ( $error ) {
%   $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "rate_time.cgi?". $cgi->query_string ) %>
% } else {
<% $cgi->redirect(popurl(3). "browse/rate_time.html" ) %>
% }
%# dumper_html(\%vars, \%old_ints, {$rate_time->intervals}) %>
<%init>
my $error = '';
die "access denied" 
    unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
my $ratetimenum = $cgi->param('ratetimenum');
my $ratetimename = $cgi->param('ratetimename');
my $delete = $cgi->param('delete');

my %vars = $cgi->Vars;
#warn Dumper(\%vars)."\n";

my $rate_time;

my %old_ints;
if( $ratetimenum ) {
  # editing
  $rate_time = FS::rate_time->by_key($ratetimenum);

  # make a list of existing intervals that will be deleted
  foreach ($rate_time->intervals) {
    $old_ints{$_->intervalnum} = $_;
  }

  if ( $delete ) {
    $error = $rate_time->delete;
    # intervals will be deleted later
  }
  elsif( $ratetimename ne $rate_time->ratetimename ) {
    # the only case where the rate_time itself must be replaced
    $rate_time->ratetimename($ratetimename);
    $error = $rate_time->replace;
  }
}
else { #!$ratetimenum, adding new
  $rate_time = FS::rate_time->new({ ratetimename => $ratetimename });
  $error = $rate_time->insert;
  $ratetimenum = $rate_time->ratetimenum;
}

if(!$delete and !$error) {
  foreach my $i (map { /stime(\d+)/ } keys(%vars)) {
    my $stime = str2wtime($vars{"stime$i"});
    my $etime = str2wtime($vars{"etime$i"});
    next if !defined($stime) or !defined($etime);
    #warn "$i: $stime-$etime";
    # try to avoid needlessly wiping and replacing intervals every 
    # time this is edited.
    if( %old_ints ) {
      my $this_int = qsearchs('rate_time_interval', 
                                    { ratetimenum => $ratetimenum,
                                      stime       => $stime,
                                      etime       => $etime, } );
      if($this_int) { 
        delete $old_ints{$this_int->intervalnum};
        #warn "not deleting $stime-$etime\n";
        next; #$i
      }
    }
    my $new_int = FS::rate_time_interval->new({ ratetimenum => $ratetimenum,
                                                stime       => $stime,
                                                etime       => $etime, } );
    $error = $new_int->insert;
    #warn "inserting $stime-$etime\n";
    last if $error;
  }
}
if(!$error) {
  foreach (values(%old_ints)) {
    $error = $_->delete;
    #warn "deleting ".$_->stime.' '.$_->etime."\n";
    last if $error;
  }
}

sub str2wtime {
  my %days;
  @days{qw(Sun Mon Tue Wed Thu Fri Sat)} = (0..6);
  my $str = shift;
  my ($d, $h, $m, $s, $ampm) = 
    ($str =~ /^(\w{3}) (\d{2}):(\d{2}):(\d{2}) (\w{2})$/);
  return () if !$d;
  $h += 24*$days{$d} + ($ampm eq 'PM' ? 12 : 0);
  $m += 60*$h;
  $s += 60*$m;
  return $s;
}
</%init>
