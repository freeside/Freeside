print "1..1\n";

use DBI;
use DBD::Pg;

if ($DBD::Pg::VERSION) {
    print "ok 1\n";
} else {
    print "not ok 1\n";
}
