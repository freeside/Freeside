package FS::part_export::forward_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
use FS::Record;

%info = (
  'svc'      => 'svc_forward',
  'desc'     => 'Real-time export of forwards to SQL databases ',
                #.' (vpopmail, Postfix+Courier IMAP, others?)',
  'options'  => __PACKAGE__->sql_options,
  'notes'    => <<END
Export mail forwards (svc_forward records) to SQL databases.

<BR><BR>In contrast to sqlmail, this is intended to export just svc_forward
records only, rather than a single export for svc_acct, svc_forward and
svc_domain records, to export in "default" database schemas rather than
configure the MTA or POP/IMAP server for a Freeside-specific schema, and
to be configured for different mail server setups.
END
);

1;
