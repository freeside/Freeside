print "1..1\n";
eval "use DBD::Pg 1.32";
if ( length($@) ) {
  print "ok 1 # Skipped: DBD::Pg 1.32 required for Pg";
} else {
  eval "use DBIx::DBSchema::DBD::Pg;";
  if ( length($@) ) {
    print "not ok 1\n";
  } else {
    print "ok 1\n";
  }
}
