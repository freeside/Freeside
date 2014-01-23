%if ($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(3). 'misc/order_pkg.html?'. $cgi->query_string ) %>
%} else {
%  my $show = $curuser->default_customer_view =~ /^(jumbo|packages)$/
%               ? ''
%               : ';show=packages';
%
%  my $redir_url = popurl(3);
%  if ( $svcpart ) { # for going straight to service provisining after ordering
%    $redir_url .= 'edit/'.$part_svc->svcdb.'.cgi?'.
%                    'pkgnum='.$cust_pkg->pkgnum. ";svcpart=$svcpart";
%    $redir_url .= ";qualnum=$qualnum" if $qualnum;
%  } elsif ( $quotationnum ) {
%    $redir_url .= "view/quotation.html?quotationnum=$quotationnum";
%  } else {
%    my $custnum = $cust_main->custnum;
%    my $frag = "cust_pkg". $cust_pkg->pkgnum;
%    $redir_url .=
%      "view/cust_main.cgi?custnum=$custnum$show;fragment=$frag#$frag";
%  }
% 
<% header('Package ordered') %>
  <SCRIPT TYPE="text/javascript">
    // XXX fancy ajax rebuild table at some point, but a page reload will do for now

    // XXX chop off trailing #target and replace... ?
    window.top.location = '<% $redir_url %>';

  </SCRIPT>

  </BODY></HTML>
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Order customer package');

my $cust_main;
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  my $custnum = $1;
  $cust_main = qsearchs({
    'table'     => 'cust_main',
    'hashref'   => { 'custnum' => $custnum },
    'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
  });
}

my $prospect_main;
if ( $cgi->param('prospectnum') =~ /^(\d+)$/ ) {
  my $prospectnum = $1;
  $prospect_main = qsearchs({
    'table'     => 'prospect_main',
    'hashref'   => { 'prospectnum' => $prospectnum },
    'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
  });
}

die 'no custnum or prospectnum' unless $cust_main || $prospect_main;

#probably not necessary, taken care of by cust_pkg::check
$cgi->param('pkgpart') =~ /^(\d+)$/
  or die 'illegal pkgpart '. $cgi->param('pkgpart');
my $pkgpart = $1;
$cgi->param('quantity') =~ /^(\d*)$/
  or die 'illegal quantity '. $cgi->param('quantity');
my $quantity = $1 || 1;
$cgi->param('refnum') =~ /^(\d*)$/
  or die 'illegal refnum '. $cgi->param('refnum');
my $refnum = $1;
$cgi->param('salesnum') =~ /^(\d*)$/
  or die 'illegal salesnum '. $cgi->param('salesnum');
my $salesnum = $1;
$cgi->param('contactnum') =~ /^(\-?\d*)$/
  or die 'illegal contactnum '. $cgi->param('contactnum');
my $contactnum = $1;
$cgi->param('locationnum') =~ /^(\-?\d*)$/
  or die 'illegal locationnum '. $cgi->param('locationnum');
my $locationnum = $1;
$cgi->param('discountnum') =~ /^(\-?\d*)$/
  or die 'illegal discountnum '. $cgi->param('discountnum');
my $discountnum = $1;

# for going right to a provision service after ordering a package
my( $svcpart, $part_svc ) = ( '', '' );
if ( $cgi->param('svcpart') ) {
  $cgi->param('svcpart') =~ /^(\-?\d*)$/
     or die 'illegal svcpart '. $cgi->param('svcpart');
  $svcpart = $1;
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } )
    or die "unknown svcpart $svcpart";
}

my $qualnum = '';
if ( $cgi->param('qualnum') =~ /^(\d+)$/ ) {
  $qualnum = $1;
}
my $quotationnum = '';
if ( $cgi->param('quotationnum') =~ /^(\d+)$/ ) {
  $quotationnum = $1;
}
# verify this quotation is visible to this user

my $cust_pkg = '';
my $quotation_pkg = '';
my $error = '';

my %hash = (
    'pkgpart'              => $pkgpart,
    'quantity'             => $quantity,
    'start_date'           => ( scalar($cgi->param('start_date'))
                                  ? parse_datetime($cgi->param('start_date'))
                                  : ''
                              ),
    'salesnum'             => $salesnum,
    'refnum'               => $refnum,
    'contactnum'           => $contactnum,
    'locationnum'          => $locationnum,
    'discountnum'          => $discountnum,
    #for the create a new discount case
    'discountnum__type'    => scalar($cgi->param('discountnum__type')),
    'discountnum_amount'   => scalar($cgi->param('discountnum_amount')),
    'discountnum_percent'  => scalar($cgi->param('discountnum_percent')),
    'discountnum_months'   => scalar($cgi->param('discountnum_months')),
    'discountnum_setup'    => scalar($cgi->param('discountnum_setup')),
    'contract_end'         => ( scalar($cgi->param('contract_end'))
                                  ? parse_datetime($cgi->param('contract_end'))
                                  : ''
                              ),
     'waive_setup'         => ( $cgi->param('waive_setup') eq 'Y' ? 'Y' : '' ),
);
$hash{'custnum'} = $cust_main->custnum if $cust_main;

my @cust_pkg_usageprice = ();
foreach my $quantity_param ( grep { $cgi->param($_) && $cgi->param($_) > 0 }
                               grep /^usagepricenum(\d+)_quantity$/,
                                 $cgi->param
                           )
{
  $quantity_param =~ /^usagepricenum(\d+)_quantity$/ or die 'unpossible';
  my $num = $1;
  push @cust_pkg_usageprice, new FS::cust_pkg_usageprice {
    usagepricepart => scalar($cgi->param("usagepricenum${num}_usagepricepart")),
    quantity       => scalar($cgi->param($quantity_param)),
  };
}
$hash{cust_pkg_usageprice} = \@cust_pkg_usageprice;

if ( $quotationnum ) {

  $quotation_pkg = new FS::quotation_pkg \%hash;
  $quotation_pkg->quotationnum($quotationnum);
  $quotation_pkg->prospectnum($prospect_main->prospectnum) if $prospect_main;

  #XXX handle new location
  $error = $quotation_pkg->insert;

} else {

  $cust_pkg = new FS::cust_pkg \%hash;

  $cust_pkg->no_auto( scalar($cgi->param('no_auto')) );

  my %opt = ( 'cust_pkg' => $cust_pkg );

  if ( $contactnum == -1 ) {
    my $contact = FS::contact->new({
      'custnum' => scalar($cgi->param('custnum')),
      map { $_ => scalar($cgi->param("contactnum_$_")) } qw( first last )
    });
    $opt{'contact'} = $contact;
  }

  if ( $locationnum == -1 ) {
    my $cust_location = FS::cust_location->new({
      map { $_ => scalar($cgi->param($_)) }
          ('custnum', FS::cust_main->location_fields)
    });
    $opt{'cust_location'} = $cust_location;
  } else {
    $opt{'locationnum'} = $locationnum;
  }

  $error = $cust_main->order_pkg( \%opt );

}

</%init>
