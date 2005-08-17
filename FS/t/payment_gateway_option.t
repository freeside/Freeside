BEGIN { $| = 1; print "1..1
" }
END {print "not ok 1
" unless $loaded;}
use FS::payment_gateway_option;
$loaded=1;
print "ok 1
";
