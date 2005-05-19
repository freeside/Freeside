<%

my $conf = new FS::Conf;
my $lpr = $conf->config('lpr');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $template = $2;
my $invnum = $3;
my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

        open(LPR,"|$lpr") or die "Can't open $lpr: $!";

        if ( $conf->exists('invoice_latex') ) {
          print LPR $cust_bill->print_ps('', $template); #( date )
        } else {
          print LPR $cust_bill->print_text('', $template); #( date )
        }

        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

my $custnum = $cust_bill->getfield('custnum');

print $cgi->redirect("${p}view/cust_main.cgi?$custnum");

%>
