use strict;
use Test::More tests => 20;

use DBD::Pg qw(:pg_types);

ok(PG_BOOL      == 16,   'PG_BOOL');
ok(PG_BYTEA     == 17,   'PG_BYTEA');
ok(PG_CHAR      == 18,   'PG_CHAR');
ok(PG_INT8      == 20,   'PG_INT8');
ok(PG_INT2      == 21,   'PG_INT2');
ok(PG_INT4      == 23,   'PG_INT4');
ok(PG_TEXT      == 25,   'PG_TEXT');
ok(PG_OID       == 26,   'PG_OID');
ok(PG_FLOAT4    == 700,  'PG_FLOAT4');
ok(PG_FLOAT8    == 701,  'PG_FLOAT8');
ok(PG_ABSTIME   == 702,  'PG_ABSTIME');
ok(PG_RELTIME   == 703,  'PG_RELTIME');
ok(PG_TINTERVAL == 704,  'PG_TINTERVAL');
ok(PG_BPCHAR    == 1042, 'PG_BPCHAR');
ok(PG_VARCHAR   == 1043, 'PG_VARCHAR');
ok(PG_DATE      == 1082, 'PG_DATE');
ok(PG_TIME      == 1083, 'PG_TIME');
ok(PG_DATETIME  == 1184, 'PG_DATETIME');
ok(PG_TIMESPAN  == 1186, 'PG_TIMESPAN');
ok(PG_TIMESTAMP == 1296, 'PG_TIMESTAMP');
