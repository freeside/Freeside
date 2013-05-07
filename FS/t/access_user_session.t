BEGIN { $| = 1; print "1..1\n" }
END {print "not ok 1\n" unless $loaded;}
use FS::access_user_session;
$loaded=1;
print "ok 1\n";
