package FS::cust_bill::Search;

use strict;
use FS::CurrentUser;
use FS::UI::Web;
use FS::Record qw( qsearchs dbh );
use FS::cust_main;
use FS::access_user;
use FS::Conf;
                                                                                
=item search HASHREF                                                            
                                                                                
(Class method)                                                                  
                                                                                
Returns a qsearch hash expression to search for parameters specified in
HASHREF.  In addition to all parameters accepted by search_sql_where, the
following additional parameters valid:

=over 4                                                                         

=item newest_percust

=back

=cut

sub search {
  my( $class, $params ) = @_;

  my( $count_query, $count_addl ) = ( '', '' );

  #some false laziness w/cust_bill::re_X

  $count_query = "SELECT COUNT(DISTINCT cust_bill.custnum), 'N/A', 'N/A'"
    if $params->{'newest_percust'};

  my $extra_sql = FS::cust_bill->search_sql_where( $params );
  $extra_sql = "WHERE $extra_sql" if $extra_sql;

  my $join_cust_main = FS::UI::Web::join_cust_main('cust_bill');

  # get discounted, credited, and paid amounts here, for use in report
  #
  # Testing shows that this is by far the most efficient way to do the 
  # joins. In particular it's almost 100x faster to join to an aggregate
  # query than to put the subquery in a select expression. It also makes
  # it more convenient to do arithmetic between columns, use them as sort
  # keys, etc.
  #
  # Each ends with a RIGHT JOIN cust_bill so that it includes all invnums,
  # even if they have no discounts/credits/payments; the total amount is then
  # coalesced to zero.
  my $join = "$join_cust_main
  JOIN (
    SELECT COALESCE(SUM(cust_bill_pkg_discount.amount), 0) AS discounted,
      invnum
      FROM cust_bill_pkg_discount
        JOIN cust_bill_pkg USING (billpkgnum)
        RIGHT JOIN cust_bill USING (invnum)
      GROUP BY invnum
    ) AS _discount USING (invnum)
  JOIN (
    SELECT COALESCE(SUM(cust_credit_bill.amount), 0) AS credited, invnum
      FROM cust_credit_bill
        RIGHT JOIN cust_bill USING (invnum)
      GROUP BY invnum
    ) AS _credit USING (invnum)
  JOIN (
    SELECT COALESCE(SUM(cust_bill_pay.amount), 0) AS paid, invnum
      FROM cust_bill_pay
        RIGHT JOIN cust_bill USING (invnum)
      GROUP BY invnum
    ) AS _pay USING (invnum)
  ";

  unless ( $count_query ) {

    my $money = (FS::Conf->new->config('money_char') || '$') . '%.2f';

    $count_query = 'SELECT COUNT(*), '. join(', ',
                     map "SUM($_)",
                         ( 'charged + discounted',
                           'discounted',
                           'credited',
                           'charged - credited',
                           'charged - credited - paid',
                         )
                   );
    $count_addl = [ "$money sales (gross)",
                    "&minus; $money discounted",
                    "&minus; $money credited",
                    "= $money sales (net)",
                    "$money outstanding balance",
                  ];
  }
  $count_query .=  " FROM cust_bill $join $extra_sql";

  #$sql_query =
  +{
    'table'     => 'cust_bill',
    'addl_from' => $join,
    'hashref'   => {},
    'select'    => join(', ',
                     'cust_bill.*',
                     #( map "cust_main.$_", qw(custnum last first company) ),
                     'cust_main.custnum as cust_main_custnum',
                     FS::UI::Web::cust_sql_fields(),
                     '(charged + discounted) as gross',
                     'discounted',
                     'credited',
                     '(charged - credited) as net',
                     '(charged - credited - paid) as owed',
                   ),
    'extra_sql' => $extra_sql,
    'order_by'  => 'ORDER BY '. ( $params->{'order_by'} || 'cust_bill._date' ),

    'count_query' => $count_query,
    'count_addl'  => $count_addl,
  };

}

=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Valid parameters are

=over 4

=item _date

List reference of start date, end date, as UNIX timestamps.

=item invnum_min

=item invnum_max

=item agentnum

=item cust_status

=item cust_classnum

List reference

=item charged

List reference of charged limits (exclusive).

=item owed

List reference of charged limits (exclusive).

=item open

flag, return open invoices only

=item net

flag, return net invoices only

=item days

=item newest_percust

=item custnum

Return only invoices belonging to that customer.

=item cust_classnum

Limit to that customer class (single value or arrayref).

=item payby

Limit to customers with that payment method (single value or arrayref).

=item refnum

Limit to customers with that advertising source.

=back

Note: validates all passed-in data; i.e. safe to use with unchecked CGI params.

=cut

sub search_sql_where {
  my($class, $param) = @_;
  #if ( $cust_bill::DEBUG ) {
  #  warn "$me search_sql_where called with params: \n".
  #       join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  #}

  #some false laziness w/cust_bill::re_X

  my @search = ();

  #agentnum
  if ( $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.agentnum = $1";
  }

  #refnum
  if ( $param->{'refnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.refnum = $1";
  }

  #custnum
  if ( $param->{'custnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.custnum = $1";
  }

  #cust_status
  if ( $param->{'cust_status'} =~ /^([a-z]+)$/ ) {
    push @search, FS::cust_main->cust_status_sql . " = '$1' ";
  }

  #customer classnum (false laziness w/ cust_main/Search.pm)
  if ( $param->{'cust_classnum'} ) {

    my @classnum = ref( $param->{'cust_classnum'} )
                     ? @{ $param->{'cust_classnum'} }
                     :  ( $param->{'cust_classnum'} );

    @classnum = grep /^(\d*)$/, @classnum;

    if ( @classnum ) {
      push @search, 'COALESCE(cust_main.classnum, 0) IN ('.join(',', @classnum).')';
    }

  }

  #payby
  if ( $param->{payby} ) {
    my $payby = $param->{payby};
    $payby = [ $payby ] unless ref $payby;
    my $payby_in = join(',', map {dbh->quote($_)} @$payby);
    push @search, "cust_main.payby IN($payby_in)" if length($payby_in);
  }

  #_date
  if ( $param->{_date} ) {
    my($beginning, $ending) = @{$param->{_date}};

    push @search, "cust_bill._date >= $beginning",
                  "cust_bill._date <  $ending";
  }

  #invnum
  if ( $param->{'invnum_min'} =~ /^\s*(\d+)\s*$/ ) {
    push @search, "cust_bill.invnum >= $1";
  }
  if ( $param->{'invnum_max'} =~ /^\s*(\d+)\s*$/ ) {
    push @search, "cust_bill.invnum <= $1";
  }

  # these are from parse_lt_gt, and should already be sanitized
  #charged
  if ( $param->{charged} ) {
    my @charged = ref($param->{charged})
                    ? @{ $param->{charged} }
                    : ($param->{charged});

    push @search, map { s/^charged/cust_bill.charged/; $_; }
                      @charged;
  }

  #my $owed_sql = FS::cust_bill->owed_sql;
  my $owed_sql = '(cust_bill.charged - credited - paid)';
  my $net_sql = '(cust_bill.charged - credited)';

  #owed
  if ( $param->{owed} ) {
    my @owed = ref($param->{owed})
                 ? @{ $param->{owed} }
                 : ($param->{owed});
    push @search, map { s/^owed/$owed_sql/ } @owed;
  }

  #open/net flags
  push @search, "0 != $owed_sql"
    if $param->{'open'};
  push @search, "0 != $net_sql"
    if $param->{'net'};

  #days
  push @search, "cust_bill._date < ". (time-86400*$param->{'days'})
    if $param->{'days'};

  #newest_percust
  if ( $param->{'newest_percust'} ) {

    #$distinct = 'DISTINCT ON ( cust_bill.custnum )';
    #$orderby = 'ORDER BY cust_bill.custnum ASC, cust_bill._date DESC';

    my @newest_where = map { my $x = $_;
                             $x =~ s/\bcust_bill\./newest_cust_bill./g;
                             $x;
                           }
                           grep ! /^cust_main./, @search;
    my $newest_where = scalar(@newest_where)
                         ? ' AND '. join(' AND ', @newest_where)
			 : '';


    push @search, "cust_bill._date = (
      SELECT(MAX(newest_cust_bill._date)) FROM cust_bill AS newest_cust_bill
        WHERE newest_cust_bill.custnum = cust_bill.custnum
          $newest_where
    )";

  }

  #promised_date - also has an option to accept nulls
  if ( $param->{promised_date} ) {
    my($beginning, $ending, $null) = @{$param->{promised_date}};

    push @search, "(( cust_bill.promised_date >= $beginning AND ".
                    "cust_bill.promised_date <  $ending )" .
                    ($null ? ' OR cust_bill.promised_date IS NULL ) ' : ')');
  }

  #agent virtualization
  my $curuser = $FS::CurrentUser::CurrentUser;
  if ( $curuser->username eq 'fs_queue'
       && $param->{'CurrentUser'} =~ /^(\w+)$/ ) {
    my $username = $1;
    my $newuser = qsearchs('access_user', {
      'username' => $username,
      'disabled' => '',
    } );
    if ( $newuser ) {
      $curuser = $newuser;
    } else {
      #warn "$me WARNING: (fs_queue) can't find CurrentUser $username\n";
      warn "[FS::cust_bill::Search] WARNING: (fs_queue) can't find CurrentUser $username\n";
    }
  }
  push @search, $curuser->agentnums_sql;

  join(' AND ', @search );

}

1;

