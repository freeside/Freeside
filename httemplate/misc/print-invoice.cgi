<%

my $conf = new FS::Conf;
my $lpr = $conf->config('lpr');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d*)$/;
my $invnum = $1;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

        open(LPR,"|$lpr") or die "Can't open $lpr: $!";

        if ( $conf->exists('invoice_latex') ) {
          print LPR $cust_bill->print_ps; #( date )
        } else {
          print LPR $cust_bill->print_text; #( date )
        }

        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

my $custnum = $cust_bill->getfield('custnum');

print $cgi->redirect(popurl(2). "view/cust_main.cgi?$custnum#history");

%>
