<%

use FS::UID qw(dbh);

my $dbh = dbh;
local $FS::UID::AutoCommit=0;

sub check {
  my $error = shift;
  if($error) {
    $cgi->param('error', $error);
    print $cgi->redirect(popurl(3) . "edit/router.cgi?". $cgi->query_string);
    $dbh->rollback;
    exit;
  }
}

my $error = '';
my $routernum  = $cgi->param('routernum');
my $routername = $cgi->param('routername');
my $old = qsearchs('router', { routernum => $routernum });
my @old_rf;
my @old_psr;

my $new = new FS::router {
    routernum  => $routernum,
    routername => $routername,
    svcnum     => 0
    };

if($old) {
  if($old->routername ne $new->routername) {
    $error = $new->replace($old);
  } #else do nothing
} else {
  $error = $new->insert;
}

check($error);

if ($old) {
  @old_psr = $old->part_svc_router;
  foreach $psr (@old_psr) {
    if($cgi->param('svcpart_'.$psr->svcpart) eq 'ON') {
      # do nothing
    } else {
      $error = $psr->delete;
    }
  }
  check($error);
  @old_rf = $old->router_field;
  foreach $rf (@old_rf) {
    if(my $new_val = $cgi->param('rf_'.$rf->routerfieldpart)) {
      if($new_val ne $rf->value) {
        my $new_rf = new FS::router_field 
	  { routernum       => $routernum,
	    value           => $new_val,
	    routerfieldpart => $rf->routerfieldpart };
	$error = $new_rf->replace($rf);
      } #else do nothing
    } else {
      $error = $rf->delete;
    }
    check($error);
  }
}

foreach($cgi->param) {
  if($cgi->param($_) eq 'ON' and /^svcpart_(\d+)$/) {
    my $svcpart = $1;
    if(grep {$_->svcpart == $svcpart} @old_psr) {
      # do nothing
    } else {
      my $new_psr = new FS::part_svc_router { svcpart   => $svcpart,
                                              routernum => $routernum };
      $error = $new_psr->insert;
    }
    check($error);
  } elsif($cgi->param($_) ne '' and /^rf_(\d+)$/) {
    my $part = $1;
    if(my @x = grep {$_->routerfieldpart == $part} @old_rf) {
      # already handled all of these
    } else {
      my $new_rf = new FS::router_field
        { routernum       => $routernum,
	  value           => $cgi->param('rf_'.$part),
	  routerfieldpart => $part };
      $error = $new_rf->insert;
      check($error);
    }
  }
}



# Yay, everything worked!
$dbh->commit or die $dbh->errstr;
print $cgi->redirect(popurl(3). "edit/router.cgi?$routernum");

%>
