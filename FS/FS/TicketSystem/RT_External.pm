package FS::TicketSystem::RT_External;

use strict;
use vars qw( $conf $priority_field $priority_field_queue $field );
use FS::UID;

install_callback FS::UID sub { 
  my $conf = new FS::Conf;
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
};

sub num_customer_tickets {
  my( $self, $custnum, $priority, $dbh ) = @_;

  #$dbh ||= create one from some config options

  my @param = ();
  my $priority_sql = '';
  if ( defined($priority) ) {
    if ( length($priority) ) {
      my $queue_sql = " queue = ( select id from queues where queues.name = ? )
                        or ( ? = '' and queue = 0 )";
      $priority_sql = "
        and ? = ( select content from TicketCustomFieldValues
                   where ticket = tickets.id
                     and customfield = ( select id from customfields
                                          where name = ?
                                            and ( $queue_sql )
                                       )
                )
      ";
      push @param, $priority,
                   $priority_field,
                   $priority_field_queue,
                   $priority_field_queue;
    } else {
      return '0nothandledyet0';
    }
  }

  my $sql = "
    select count(*) from tickets 
       where ( status = 'new' or status = 'open' or status = 'stalled' )
         and target = 'freeside://freeside/cust_main/$custnum'
  ";

  my $sth = $dbh->prepare($sql) or die $dbh->errstr;
  $sth->execute(@param)         or die $sth->errstr;

  $sth->fetchrow_arrayref->[0];

}

sub href_customer_tickets {
  my( $self, $custnum, $priority ) = @_;

  my $href = 
    'Search/Results.html?Order=ASC&Query=%20MemberOf%20%3D%20%27freeside%3A%2F%2Ffreeside%2Fcust_main%2F'.
    $custnum.
    '%27%20%20AND%20%28%20Status%20%3D%20%27open%27%20%20OR%20Status%20%3D%20%27new%27%20%20OR%20Status%20%3D%20%27stalled%27%20%29%20'
  ;

  if ( $priority && $field && $priority_field_queue ) {
    $href .= 'AND%20Queue%20%3D%20%27'. $priority_field_queue. '%27%20';
  }
  if ( $priority && $field ) {
    $href .= '%20AND%20%27CF.'. $field. '%27%20%3D%20%27'. $priority. '%27%20';
  }

  $href .= '&Rows=100'.
           '&OrderBy=id&Page=1'.
           '&Format=%27%20%20%20%3Cb%3E%3Ca%20href%3D%22%2Ffreeside%2Frt%2FTicket%2FDisplay.html%3Fid%3D__id__%22%3E__id__%3C%2Fa%3E%3C%2Fb%3E%2FTITLE%3A%23%27%2C%20%0A%27%3Cb%3E%3Ca%20href%3D%22%2Ffreeside%2Frt%2FTicket%2FDisplay.html%3Fid%3D__id__%22%3E__Subject__%3C%2Fa%3E%3C%2Fb%3E%2FTITLE%3ASubject%27%2C%20%0A%27__Status__%27%2C%20';

  if ( $priority && $field ) {
    $href .= '%0A%27__CustomField.'. $field. '__%2FTITLE%3ASeverity%27%2C%20';
  }

  $href .= '%0A%27__QueueName__%27%2C%20%0A%27__OwnerName__%27%2C%20%0A%27__Priority__%27%2C%20%0A%27__NEWLINE__%27%2C%20%0A%27%27%2C%20%0A%27%3Csmall%3E__Requestors__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__CreatedRelative__%3C%2Fsmall%3E%27%2C';

  if ( $priority && $field ) {
    $href .=   '%20%0A%27__-__%27%2C';
  }

  $href .= '%20%0A%27%3Csmall%3E__ToldRelative__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__LastUpdatedRelative__%3C%2Fsmall%3E%27%2C%20%0A%27%3Csmall%3E__TimeLeft__%3C%2Fsmall%3E%27';

  $href;
}

1;

