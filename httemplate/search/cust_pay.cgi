<%
   my( $count_query, $sql_query );
   if ( $cgi->param('magic') && $cgi->param('magic') eq '_date' ) {
   
     my %search;
     my @search;
   
     if ( $cgi->param('payby') ) {
       $cgi->param('payby') =~ /^(CARD|CHEK|BILL)(-(VisaMC|Amex|Discover))?$/
         or die "illegal payby ". $cgi->param('payby');
       $search{'payby'} = $1;
       if ( $3 ) {
         if ( $3 eq 'VisaMC' ) {
           #avoid posix regexes for portability
           push @search, " (    substring(payinfo from 1 for 1) = '4'  ".
                         "   OR substring(payinfo from 1 for 2) = '51' ".
                         "   OR substring(payinfo from 1 for 2) = '52' ".
                         "   OR substring(payinfo from 1 for 2) = '53' ".
                         "   OR substring(payinfo from 1 for 2) = '54' ".
                         "   OR substring(payinfo from 1 for 2) = '54' ".
                         "   OR substring(payinfo from 1 for 2) = '55' ".
                         " ) ";
         } elsif ( $3 eq 'Amex' ) {
           push @search, " (    substring(payinfo from 1 for 2 ) = '34' ".
                         "   OR substring(payinfo from 1 for 2 ) = '37' ".
                         " ) ";
         } elsif ( $3 eq 'Discover' ) {
           push @search, " substring(payinfo from 1 for 4 ) = '6011' ";
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
   
     my $search;
     if ( @search ) {
       $search = ( scalar(keys %search) ? ' AND ' : ' WHERE ' ).
                 join(' AND ', @search);
     }

     my $hsearch = join(' AND ', map { "$_ = '$search{$_}'" } keys %search );
     $count_query = "SELECT COUNT(*), SUM(paid) FROM cust_pay ".
                    ( $hsearch ? " WHERE $hsearch " : '' ).
                    $search;
   
     $sql_query = {
       'table'     => 'cust_pay',
       'hashref'   => \%search,
       'extra_sql' => "$search ORDER BY _date",
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

%>
<%= include( 'elements/search.html',
               'title'       => 'Payment Search Results',
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
                 sub { my $cust_main = shift->cust_main;
                       $cust_main->get('last'). ', '. $cust_main->first;
                     },
                 sub { my $cust_main = shift->cust_main;
                       $cust_main->company;
                     },
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
