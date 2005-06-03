package FS::TicketSystem::RT_External;

use strict;
use vars qw( $conf $default_queueid
             $priority_field $priority_field_queue $field
	     $external_dbh $external_url );
use URI::Escape;
use FS::UID;

install_callback FS::UID sub { 
  my $conf = new FS::Conf;
  $default_queueid = $conf->config('ticket_system-default_queueid');
  $priority_field =
    $conf->config('ticket_system-custom_priority_field');
  if ( $priority_field ) {
    $priority_field_queue =
      $conf->config('ticket_system-custom_priority_field_queue');
    $field = $priority_field_queue
                  ? $priority_field_queue. '.%7B'. $priority_field. '%7D'
                  : $priority_field;
  } else {
    $priority_field_queue = '';
    $field = '';
  }

  $external_url = '';
  if ($conf->config('ticket_system') eq 'RT_External') {
    my ($datasrc, $user, $pass) = $conf->config('ticket_system-rt_external_datasrc');
    $external_dbh = DBI->connect($datasrc, $user, $pass, { 'ChopBlanks' => 1 })
      or die "RT_External DBI->connect error: $DBI::errstr\n";

    $external_url = $conf->config('ticket_system-rt_external_url');
  }

};

sub num_customer_tickets {
  my( $self, $custnum, $priority, $dbh ) = @_;

  $dbh ||= $external_dbh;

  my( $from_sql, @param) = $self->_from_customer( $custnum, $priority );

  my $sql = "select count(*) $from_sql";
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. " preparing $sql";
  $sth->execute(@param)         or die $sth->errstr. " executing $sql";

  $sth->fetchrow_arrayref->[0];

}

sub customer_tickets {
  my( $self, $custnum, $limit, $priority, $dbh ) = @_;
  $limit ||= 0;

  $dbh ||= $external_dbh;

  my( $from_sql, @param) = $self->_from_customer( $custnum, $priority );
  my $sql = "select tickets.*, queues.name".
            ( length($priority) ? ", ticketcustomfieldvalues.content" : '' ).
            " $from_sql order by priority desc limit $limit";
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. "preparing $sql";
  $sth->execute(@param)         or die $sth->errstr. "executing $sql";

  #munge column names???  #httemplate/view/cust_main/tickets.html has column
  #names that might not make sense now...
  $sth->fetchall_arrayref({});

}

sub _from_customer {
  my( $self, $custnum, $priority ) = @_;

  my @param = ();
  my $join = '';
  my $where = '';
  if ( defined($priority) ) {

    my $queue_sql = " customfields.queue = ( select id from queues
                                              where queues.name = ? )
                      or ( ? = '' and customfields.queue = 0 )";

    if ( length($priority) ) {
      #$where = "    
      #  and ? = ( select content from TicketCustomFieldValues
      #             where ticket = tickets.id
      #               and customfield = ( select id from customfields
      #                                    where name = ?
      #                                      and ( $queue_sql )
      #                                 )
      #          )
      #";
      push @param, $priority;

      $join = "join TicketCustomFieldValues
                 on ( tickets.id = TicketCustomFieldValues.ticket )";
      
      $where = "and content = ?
                and customfield = ( select id from customfields
                                     where name = ?
                                       and ( $queue_sql )
                                  )
               ";
    } else {
      $where =
               "and 0 = ( select count(*) from TicketCustomFieldValues
                           where ticket = tickets.id
                             and customfield = ( select id from customfields
                                                  where name = ?
                                                    and ( $queue_sql )
                                               )
                        )
               ";
    }
    push @param, $priority_field,
                 $priority_field_queue,
                 $priority_field_queue;
  }

  my $sql = "
                    from tickets
                    join queues on ( tickets.queue = queues.id )
                    join links on ( tickets.id = links.localbase )
                    $join 
       where ( status = 'new' or status = 'open' or status = 'stalled' )
         and target = 'freeside://freeside/cust_main/$custnum'
         $where
  ";

  ( $sql, @param );

}

sub _href_customer_tickets {
  my( $self, $custnum, $priority ) = @_;

  #i snarfed this from an RT bookmarked search, it could be unescaped in the
  #source for readability and run through uri_escape
  my $href = 
    'Search/Results.html?Order=ASC&Query=%20MemberOf%20%3D%20%27freeside%3A%2F%2Ffreeside%2Fcust_main%2F'.
    $custnum.
    '%27%20%20AND%20%28%20Status%20%3D%20%27open%27%20%20OR%20Status%20%3D%20%27new%27%20%20OR%20Status%20%3D%20%27stalled%27%20%29%20'
  ;

  if ( defined($priority) && $field && $priority_field_queue ) {
    $href .= 'AND%20Queue%20%3D%20%27'. $priority_field_queue. '%27%20';
  }
  if ( defined($priority) && $field ) {
    $href .= '%20AND%20%27CF.'. $field. '%27%20';
    if ( $priority ) {
      $href .= '%3D%20%27'. $priority. '%27%20';
    } else {
      $href .= 'IS%20%27NULL%27%20';
    }
  }

  $href .= '&Rows=100'.
           '&OrderBy=id&Page=1'.
           '&Format=%27%20%20%20%3Cb%3E%3Ca%20href%3D%22'.
	   $self->baseurl.
	   'Ticket%2FDisplay.html%3Fid%3D__id__%22%3E__id__%3C%2Fa%3E%3C%2Fb%3E%2FTITLE%3A%23%27%2C%20%0A%27%3Cb%3E%3Ca%20href%3D%22'.
	   $self->baseurl.
	   'Ticket%2FDisplay.html%3Fid%3D__id__%22%3E__Subject__%3C%2Fa%3E%3C%2Fb%3E%2FTITLE%3ASubject%27%2C%20%0A%27__Status__%27%2C%20';

  if ( defined($priority) && $field ) {
    $href .= '%0A%27__CustomField.'. $field. '__%2FTITLE%3ASeverity%27%2C%20';
  }

  $href .= '%0A%27__QueueName__%27%2C%20%0A%27__OwnerName__%27%2C%20%0A%27__Priority__%27%2C%20%0A%27__NEWLINE__%27%2C%20%0A%27%27%2C%20%0A%27%3Csmall%3E__Requestors__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__CreatedRelative__%3C%2Fsmall%3E%27%2C';

  if ( defined($priority) && $field ) {
    $href .=   '%20%0A%27__-__%27%2C';
  }

  $href .= '%20%0A%27%3Csmall%3E__ToldRelative__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__LastUpdatedRelative__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__TimeLeft__%3C%2Fsmall%3E%27';

  $href;

}

sub href_customer_tickets {
  my $self = shift;
  $self->baseurl. $self->_href_customer_tickets(@_);
}


sub _href_new_ticket {
  my( $self, $custnum, $requestors ) = @_;

  'Ticket/Create.html?'.
    "Queue=$default_queueid".
    "&new-MemberOf=freeside://freeside/cust_main/$custnum".
    ( $requestors ? '&Requestors='. uri_escape($requestors) : '' )
    ;
}

sub href_new_ticket {
  my $self = shift;
  $self->baseurl. $self->_href_new_ticket(@_);
}

sub _href_ticket {
  my($self, $ticketnum) = @_;
  'Ticket/Display.html?id='.$ticketnum;
}

sub href_ticket {
  my $self = shift;
  $self->baseurl. $self->_href_ticket(@_);
}

sub baseurl {
  #my $self = shift;
  $external_url;
}

1;

