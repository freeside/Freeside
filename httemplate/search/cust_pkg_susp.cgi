<% include('/elements/header.html', $title) %>
<% include('/elements/table-grid.html') %>
  <TR>
% foreach (@head) {
    <TH CLASS="grid" BGCOLOR="#cccccc"><% $_ %></TH>
% }
  </TR>
% my $r=0;
% foreach my $row (@rows) {
  <TR>
%   foreach (@$row) {
    <TD CLASS="grid" STYLE="border: 1px solid #cccccc" ALIGN="right" BGCOLOR="<% $r % 2 ? '#ffffff' : '#eeeeee' %>"><% $_ %></TD>
%   }
  </TR>
%   $r++;
% }
  <TR>
% foreach (@totals) {
    <TD CLASS="grid" STYLE="border: 1px solid #cccccc" ALIGN="right" BGCOLOR="<% $r % 2 ? '#ffffff' : '#eeeeee' %>"><B><% $_ %></B></TD>
% }
  </TR>
</TABLE>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List packages');

my $money_char = FS::Conf->new()->config('money_char') || '$';

$FS::Record::DEBUG=0;

my $title = 'Suspension/Unsuspension Report';
my ($begin, $end) = FS::UI::Web::parse_beginning_ending($cgi);
if($begin > 0) {
  $title = "$title (".
    ($cgi->param('beginning') || 'beginning').' - '.
    ($cgi->param('ending') || 'present').')';
}


my $begin_sql = $begin ? "AND h2.history_date > $begin" : '';
my $end_sql   = $end   ? "AND h2.history_date < $end" : '';

my $h_sql = # self-join FTW!
"SELECT h1.pkgpart, count(h1.pkgnum) as pkgcount
  FROM h_cust_pkg AS h1 INNER JOIN h_cust_pkg AS h2 ON (h1.pkgnum = h2.pkgnum)
  WHERE h1.history_action = 'replace_old' AND h2.history_action = 'replace_new'
  AND h2.historynum - h1.historynum = 1
  $begin_sql $end_sql";
# This assumes replace_old and replace_new records get consecutive 
# numbers. That's true in every case I've seen but is not actually 
# enforced anywhere.  If this is a problem we can match them up 
# line by line but that's cumbersome.

my @conds = (
  '(h1.susp is null OR h1.susp = 0) AND (h2.susp is not null AND h2.susp != 0)',
  '(h1.susp is not null AND h1.susp != 0) AND (h2.susp is null OR h2.susp = 0)',
);

my @results;
foreach my $cond (@conds) {
  my $sql = "$h_sql AND $cond GROUP BY h1.pkgpart";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute() or die $sth->errstr;
  push @results, { map { @$_ } @{ $sth->fetchall_arrayref() } };
} 
 
my @pay_cond;
push @pay_cond, "cust_bill_pay._date < $end" if $end;
push @pay_cond, "cust_bill_pay._date > $begin" if $begin;

my $pay_cond = '';
$pay_cond = 'WHERE '.join(' AND ', @pay_cond) if @pay_cond;

my $pkg_payments = {
  map { $_->pkgpart => $_->total_pay }
  qsearch({
    'table'     => 'cust_pkg',
    'select'    => 'pkgpart, sum(cust_bill_pay_pkg.amount) AS total_pay',
    'addl_from' => 'INNER JOIN cust_bill_pkg USING (pkgnum)
                    INNER JOIN cust_bill_pay_pkg USING (billpkgnum)
                    INNER JOIN cust_bill_pay USING (billpaynum)',
    'extra_sql' => $pay_cond . ' GROUP BY pkgpart',
}) };

my @head = ('Package', 'Suspended', 'Unsuspended', 'Payments');
my @rows = ();
my @totals = map {0} @head;
$totals[0] = 'Total';

foreach my $part_pkg (qsearch('part_pkg', {} )) {
  my @row = ();
  next if !$part_pkg->freq; # exclude one-time packages
  my $pkgpart = $part_pkg->pkgpart;
  push @row, 
    $part_pkg->pkg,
    $results[0]->{$pkgpart} || 0,
    $results[1]->{$pkgpart} || 0,
    sprintf("%.02f",$pkg_payments->{$pkgpart});

  $totals[$_] += $row[$_] foreach (1..3);
  $row[3] = $money_char.$row[3];

  push @rows, \@row;
}
$totals[3] = $money_char.$totals[3];

</%init>
