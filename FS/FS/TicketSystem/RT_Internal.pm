package FS::TicketSystem::RT_Internal;

use strict;
use vars qw( @ISA );
use FS::UID qw(dbh);
use FS::CGI qw(popurl);
use FS::TicketSystem::RT_Libs;

@ISA = qw( FS::TicketSystem::RT_Libs );

sub sql_num_customer_tickets {
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

sub customer_tickets {
  my( $self, $custnum, $limit, $priority ) = ( shift, shift, shift, shift );
  $self->SUPER::customer_tickets( $custnum, $limit, $priority, dbh );
}

sub href_customer_tickets {
  my $self = shift;
  # well, 2 is wrong here but will have to do for now
  popurl(2).'rt/'. $self->SUPER::href_customer_tickets(@_);
}

sub href_new_ticket {
  my $self = shift;
  # well, 2 is wrong here but will have to do for now
  popurl(2).'rt/'. $self->SUPER::href_new_ticket(@_);
}

sub href_ticket {
  my $self = shift;
  # well, 2 is wrong here but will have to do for now
  popurl(2).'rt/'. $self->SUPER::href_ticket(@_);
}

1;

