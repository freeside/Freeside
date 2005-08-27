BEGIN { $| = 1; print "1..1
" }
END {print "not ok 1
" unless $loaded;}
use FS::cancel_reason;
$loaded=1;
print "ok 1
";
