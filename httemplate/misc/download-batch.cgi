%if ($format eq "BoM") {
%
%  my($origid,$datacenter,$typecode,$shortname,$longname,$mybank,$myacct) =
%    $conf->config("batchconfig-$format");
%  
<% sprintf( "A%10s%04u%06u%05u%54s\n",$origid,$pay_batch->batchnum,$jdate,$datacenter,"").
        sprintf( "XD%03u%06u%-15s%-30s%09u%-12s   \n",$typecode,$jdate,$shortname,$longname,$mybank,$myacct )
  %>
%
%}elsif ($format eq "PAP"){
%
%  my($origid,$datacenter,$typecode,$shortname,$longname,$mybank,$myacct) =
%    $conf->config("batchconfig-$format");
%  
<% sprintf( "H%10sD%3s%06u%-15s%09u%-12s%04u%19s\n",$origid,$typecode,$cdate,$shortname,$mybank,$myacct,$pay_batch->batchnum,"") %>
%
%
%}elsif ($format eq "csv-td_canada_trust-merchant_pc_batch"){
%#  1;
%}elsif ($format eq "csv-chase_canada-E-xactBatch"){
%
%  my($origid) = $conf->config("batchconfig-$format");
<% sprintf( '$$E-xactBatchFileV1.0$$%s:%03u$$%s',$sdate,$pay_batch->batchnum, $origid)
  %>
%
%}else{
%  die "Unknown format for batch in batchconfig. \n";
%}
%
%
%for my $cust_pay_batch ( sort { $a->paybatchnum <=> $b->paybatchnum }
%                           qsearch('cust_pay_batch',
%			      {'batchnum'=>$pay_batch->batchnum} )
%) {
%
%  $cust_pay_batch->exp =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
%  my( $mon, $y ) = ( $2, $1 );
%  if ( $conf->exists('batch-increment_expiration') ) {
%    my( $curmon, $curyear ) = (localtime(time))[4,5];
%    $curmon++; $curyear-=100;
%    $y++ while $y < $curyear || ( $y == $curyear && $mon < $curmon );
%  }
%  $mon = "0$mon" if $mon =~ /^\d$/;
%  $y = "0$y" if $y =~ /^\d$/;
%  my $exp = "$mon$y";
%
%  if ( $first_download ) {
%    my $balance = $cust_pay_batch->cust_main->balance;
%    if ( $balance <= 0 ) {
%      my $error = $cust_pay_batch->delete;
%      if ( $error ) {
%        $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
%        die $error;
%      }
%      next;
%    } elsif ( $balance < $cust_pay_batch->amount ) {
%      $cust_pay_batch->amount($balance);
%      my $error = $cust_pay_batch->replace;
%      if ( $error ) {
%        $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
%        die $error;
%      }
%    #} elsif ( $balance > $cust_pay_batch->amount ) {
%    } 
%  }
%
%  $batchcount++;
%  $batchtotal += $cust_pay_batch->amount;
%  
%  if ($format eq "BoM") {
%
%    my( $account, $aba ) = split( '@', $cust_pay_batch->payinfo );
%    
<% sprintf( "D%010.0f%09u%-12s%-29s%-19s\n",$cust_pay_batch->amount*100,$aba,$account,$cust_pay_batch->payname,$cust_pay_batch->paybatchnum) %>
%
%
%  } elsif ($format eq "PAP"){
%
%    my( $account, $aba ) = split( '@', $cust_pay_batch->payinfo );
%    
<% sprintf( "D%-23s%06u%-19s%09u%-12s%010.0f\n",$cust_pay_batch->payname,$cdate,$cust_pay_batch->paybatchnum,$aba,$account,$cust_pay_batch->amount*100) %>
%
%
%  } elsif ($format eq "csv-td_canada_trust-merchant_pc_batch") {
%
%    
,,,,<% $cust_pay_batch->payinfo %>,<% $exp %>,<% $cust_pay_batch->amount %>,<% $cust_pay_batch->paybatchnum %>
%
%
%  } elsif ($format eq "csv-chase_canada-E-xactBatch"){
%
%  my $payname=$cust_pay_batch->payname; $payname =~ tr/",/  /; #payinfo too? :P
<% $cust_pay_batch->paybatchnum %>,<% $cust_pay_batch->custnum %>,<% $cust_pay_batch->invnum %>,"<% $payname %>",00,<% $cust_pay_batch->payinfo %>,<% $cust_pay_batch->amount %>,<% $exp %>,,
%
%
%  } else {
%    die "I'm already dead, but you did not know that.\n";
%  }
%
%}
%
%if ($format eq "BoM") {
%
%  
<% sprintf( "YD%08u%014.0f%56s\n",$batchcount,$batchtotal*100,"" ).
        sprintf( "Z%014u%05u%014u%05u%41s\n",$batchtotal*100,$batchcount,"0","0","" ) %>
%
%
%} elsif ($format eq "PAP"){
%
%  
<% sprintf( "T%08u%014.0f%57s\n",$batchcount,$batchtotal*100,"" ) %>
%
%
%} elsif ($format eq "csv-td_canada_trust-merchant_pc_batch"){
%  #1;
%} elsif ($format eq "csv-chase_canada-E-xactBatch"){
%  #1;
%} else {
%  die "I'm already dead (again), but you did not know that.\n";
%}
%
%$dbh->commit or die $dbh->errstr if $oldAutoCommit;
<%init>

my $conf=new FS::Conf;

#http_header('Content-Type' => 'text/comma-separated-values' ); #IE chokes
http_header('Content-Type' => 'text/plain' );

my $batchnum;
if ( $cgi->param('batchnum') =~ /^(\d+)$/ ) {
  $batchnum = $1;
} else {
  die "No batch number (bad URL) \n";
}

my $format;
if ( $cgi->param('format') =~ /^([\w\- ]+)$/ ) {
  $format = $1;
} else {
  $format = $conf->config('batch-default_format');
}

my $oldAutoCommit = $FS::UID::AutoCommit;
local $FS::UID::AutoCommit = 0;
my $dbh = dbh;

my $pay_batch = qsearchs('pay_batch', {'batchnum'=>$batchnum, 'status'=>'O'} );
my $first_download = 1;
unless ($pay_batch) {
  $pay_batch = qsearchs('pay_batch', {'batchnum'=>$batchnum, 'status'=>'I'} )
    if $FS::CurrentUser::CurrentUser->access_right('Reprocess batches');
  $first_download = 0;
}
die "No pending batch. \n" unless $pay_batch;

my $error = $pay_batch->set_status('I');
die "error updating batch status: $error\n" if $error;

my $batchtotal=0;
my $batchcount=0;

my (@date)=localtime($pay_batch->download);
my $jdate = sprintf("%03d", $date[5] % 100).sprintf("%03d", $date[7] + 1);
my $cdate = sprintf("%02d", $date[3]).sprintf("%02d", $date[4] + 1).
            sprintf("%02d", $date[5] % 100);
my $sdate = sprintf("%02d", $date[5] % 100).'/'.sprintf("%02d", $date[4] + 1).
            '/'.sprintf("%02d", $date[3]);

</%init>
