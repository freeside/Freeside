<% include( 'elements/cust_main_dayranges.html',
                 'title'       => 'Accounts Receivable Aging Summary',
                 'range_sub'   => \&balance,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Receivables report')
      or $FS::CurrentUser::CurrentUser->access_right('Financial reports');

</%init>
<%once>

#Example:
#
# my $balance = balance(
#   $start, $end, 
#   'no_as'  => 1, #set to true when using in a WHERE clause (supress AS clause)
#                 #or 0 / omit when using in a SELECT clause as a column
#                 #  ("AS balance_$start_$end")
#   'sum'    => 1, #set to true to get a SUM() of the values, for totals
#
#   #obsolete? options for totals (passed to cust_main::balance_date_sql)
#   'total'  => 1, #set to true to remove all customer comparison clauses
#   'join'   => $join,   #JOIN clause
#   'where'  => \@where, #WHERE clause hashref (elements "AND"ed together)
# )

sub balance {
  my($start, $end) = @_; #, %opt ?

  #handle start and end ranges (86400 = 24h * 60m * 60s)
  my $str2time = str2time_sql;
  my $closing = str2time_sql_closing;
  $start = $start ? "( $str2time now() $closing - ".($start * 86400). ' )' : '';
  $end   = $end   ? "( $str2time now() $closing - ".($end   * 86400). ' )' : '';

  #$opt{'unapplied_date'} = 1;

  FS::cust_main->balance_date_sql( $start, $end, 'unapplied_date'=>1,);

}

</%once>
