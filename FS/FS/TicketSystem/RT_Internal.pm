package FS::TicketSystem::RT_Internal;

use strict;
use vars qw( @ISA );
use FS::UID qw(dbh);
use FS::CGI qw(popurl);
use FS::TicketSystem::RT_Libs;

@ISA = qw( FS::TicketSystem::RT_Libs );

sub sql_customer_tickets {
  "( select count(*) from tickets
                     join links on ( tickets.id = links.localbase )
     where ( status = 'new' or status = 'open' or status = 'stalled' )
       and target = 'freeside://freeside/cust_main/' || custnum
   )";
}

sub num_customer_tickets {
  my( $self, $custnum, $priority ) = ( shift, shift, shift );
  $self->SUPER::num_customer_tickets( $custnum, $priority, dbh );
}

sub href_customer_tickets {
  my $self = shift;
  # well, 2 is wrong here but will have to do for now
  popurl(2).'rt/'. $self->SUPER::href_customer_tickets(@_);
}

1;

