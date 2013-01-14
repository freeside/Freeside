%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "REAL_cust_pkg.cgi?". $cgi->query_string ) %>
%} else { 
%  my $custnum = $new->custnum;
%  my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
%               ? ''
%               : ';show=packages';
%  my $frag = "cust_pkg$pkgnum"; #hack for IE ignoring real #fragment
<% $cgi->redirect(popurl(3). "view/cust_main.cgi?custnum=$custnum$show;fragment=$frag#$frag" ) %>
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Edit customer package dates');

my $pkgnum = $cgi->param('pkgnum') or die;
my $old = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
my %hash = $old->hash;
foreach ( qw( start_date setup bill last_bill contract_end ) ) {
  if ( $cgi->param($_) =~ /^(\d+)$/ ) {
    $hash{$_} = $1;
  } else {
    $hash{$_} = '';
  }
  # adjourn, expire, resume not editable this way
}

my $new;
my $error;
$new = new FS::cust_pkg \%hash;
$error = $new->replace($old);

if (!$error) {
  my @supp_pkgs = $old->supplemental_pkgs;
  foreach $new (@supp_pkgs) {
    foreach ( qw( start_date setup contract_end ) ) {
      # propagate these to supplementals
      $new->set($_, $hash{$_});
    }
    if ( $hash{'bill'} ne $old->get('bill') ) {
      if ( $hash{'bill'} and $old->get('bill') ) {
        # adjust by the same interval
        my $diff = $hash{'bill'} - $old->get('bill');
        $new->set('bill', $new->get('bill') + $diff);
      } else {
        # absolute date
        $new->set('bill', $hash{'bill'});
      }
    }
    $error = $new->replace;
    $error .= ' (supplemental package '.$new->pkgnum.')' if $error; 
    last if $error;
  }
}

</%init>
