<%
   my $title = 'Payment Search Results';
   my( $count_query, $sql_query );
   if ( $cgi->param('magic') && $cgi->param('magic') eq '_date' ) {
   
     my @search = ();

     if ( $cgi->param('agentnum') && $cgi->param('agentnum') =~ /^(\d+)$/ ) {
       push @search, "agentnum = $1"; # $search{'agentnum'} = $1;
       my $agent = qsearchs('agent', { 'agentnum' => $1 } );
       die "unknown agentnum $1" unless $agent;
       $title = $agent->agent. " $title";
     }
   
     if ( $cgi->param('payby') ) {
       $cgi->param('payby') =~ /^(CARD|CHEK|BILL)(-(VisaMC|Amex|Discover))?$/
         or die "illegal payby ". $cgi->param('payby');
       push @search, "cust_pay.payby = '$1'";
       if ( $3 ) {
         if ( $3 eq 'VisaMC' ) {
           #avoid posix regexes for portability
           push @search,
             " (    substring(cust_pay.payinfo from 1 for 1) = '4'  ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '51' ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '52' ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '53' ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '54' ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '54' ".
             "   OR substring(cust_pay.payinfo from 1 for 2) = '55' ".
             " ) ";
         } elsif ( $3 eq 'Amex' ) {
           push @search,
             " (    substring(cust_pay.payinfo from 1 for 2 ) = '34' ".
             "   OR substring(cust_pay.payinfo from 1 for 2 ) = '37' ".
             " ) ";
         } elsif ( $3 eq 'Discover' ) {
           push @search,
             " substring(cust_pay.payinfo from 1 for 4 ) = '6011' ";
         } else {
           die "unknown card type $3";
         }
       }
     }
   
     #false laziness with cust_pkg.cgi
     if ( $cgi->param('beginning')
          && $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/ ) {
       my $beginning = str2time($1);
       push @search, "_date >= $beginning ";
     }
     if ( $cgi->param('ending')
               && $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/ ) {
       my $ending = str2time($1) + 86399;
       push @search, " _date <= $ending ";
     }
     if ( $cgi->param('begin')
          && $cgi->param('begin') =~ /^(\d+)$/ ) {
       push @search, "_date >= $1 ";
     }
     if ( $cgi->param('end')
               && $cgi->param('end') =~ /^(\d+)$/ ) {
       push @search, " _date < $1 ";
     }
   
     my $search = '';
     if ( @search ) {
       $search = ' WHERE '. join(' AND ', @search);
     }

     $count_query = "SELECT COUNT(*), SUM(paid) ".
                    "FROM cust_pay LEFT JOIN cust_main USING ( custnum )".
                    $search;
   
     $sql_query = {
       'table'     => 'cust_pay',
       'select'    => 'cust_pay.*, cust_main.last, cust_main.first, cust_main.company',
       'hashref'   => {},
       'extra_sql' => "$search ORDER BY _date",
       'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
     };
   
   } else {
   
     $cgi->param('payinfo') =~ /^\s*(\d+)\s*$/ or die "illegal payinfo";
     my $payinfo = $1;
   
     $cgi->param('payby') =~ /^(\w+)$/ or die "illegal payby";
     my $payby = $1;
   
     $count_query = "SELECT COUNT(*), SUM(paid) FROM cust_pay ".
                    "WHERE payinfo = '$payinfo' AND payby = '$payby'";
   
     $sql_query = {
       'table'     => 'cust_pay',
       'hashref'   => { 'payinfo' => $payinfo,
                        'payby'   => $payby    },
       'extra_sql' => "ORDER BY _date",
     };
   
   }

   my $link = [ "${p}view/cust_main.cgi?", 'custnum' ];

%><%= include( 'elements/search.html',
                 'title'       => $title,
                 'name'        => 'payments',
                 'query'       => $sql_query,
                 'count_query' => $count_query,
                 'count_addl'  => [ '$%.2f total paid', ],
                 'header'      =>
                   [ qw(Payment Amount Date), 'Cust #', 'Contact name',
                     'Company', ],
                 'fields'      => [
                   sub {
                     my $cust_pay = shift;
                     if ( $cust_pay->payby eq 'CARD' ) {
                       'Card #'. $cust_pay->payinfo_masked;
                     } elsif ( $cust_pay->payby eq 'CHEK' ) {
                       'E-check acct#'. $cust_pay->payinfo;
                     } elsif ( $cust_pay->payby eq 'BILL' ) {
                       'Check #'. $cust_pay->payinfo;
                     } else {
                       $cust_pay->payby. ' '. $cust_pay->payinfo;
                     }
                   },
                   sub { sprintf('$%.2f', shift->paid ) },
                   sub { time2str('%b %d %Y', shift->_date ) },
                   'custnum',
                   sub { $_[0]->get('last'). ', '. $_[0]->first; },
                   'company',
                 ],
                 'align' => 'lrrrll',
                 'links' => [
                   '',
                   '',
                   '',
                   $link,
                   $link,
                   $link,
                 ],
      )
%>
