package FS::TicketSystem::RT_Internal;

use strict;
use vars qw( @ISA );

@ISA = qw( FS::TicketSystem::RT_Libs );

sub sql_customer_tickets {
  "( select count(*) from tickets
                     join links on ( tickets.id = links.localbase )
     where ( status = 'new' or status = 'open' or status = 'stalled' )
       and target = 'freeside://freeside/cust_main/' || custnum
   )";
}

1;

