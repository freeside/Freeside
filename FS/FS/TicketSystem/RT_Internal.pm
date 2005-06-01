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

sub baseurl {
  #my $self = shift;
  if ( $RT::URI::freeside::URL ) {
    $RT::URI::freeside::URL. 'rt/';
  } else {
    'http://you_need_to_set_RT_URI_freeside_URL_in_SiteConfig.pm/';
  }
}

1;

