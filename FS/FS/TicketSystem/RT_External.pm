package FS::TicketSystem::RT_External;

use strict;
use vars qw( $DEBUG $me $conf $dbh $default_queueid $external_url
             $priority_reverse
             $priority_field $priority_field_queue $field
	   );
use URI::Escape;
use FS::UID qw(dbh);
use FS::Record qw(qsearchs);
use FS::cust_main;
use Carp qw(cluck);

$me = '[FS::TicketSystem::RT_External]';
$DEBUG = 0;

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $default_queueid = $conf->config('ticket_system-default_queueid');
  $priority_reverse = $conf->exists('ticket_system-priority_reverse');
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
  $dbh = dbh;
  if ($conf->config('ticket_system') eq 'RT_External') {
    my ($datasrc, $user, $pass) = $conf->config('ticket_system-rt_external_datasrc');
    $dbh = DBI->connect($datasrc, $user, $pass, { 'ChopBlanks' => 1 })
      or die "RT_External DBI->connect error: $DBI::errstr\n";

    $external_url = $conf->config('ticket_system-rt_external_url');
  }

  #kludge... should *use* the id... but good enough for now
  if ( $priority_field_queue =~ /^(\d+)$/ ) {
    my $id = $1;
    my $sql = 'SELECT Name FROM Queues WHERE Id = ?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr. " preparing $sql";
    $sth->execute($id)            or die $sth->errstr. " executing $sql";

    $priority_field_queue = $sth->fetchrow_arrayref->[0];

  }

} );

sub num_customer_tickets {
  my( $self, $custnum, $priority ) = @_;

  my( $from_sql, @param) = $self->_from_customer( $custnum, $priority );

  my $sql = "SELECT COUNT(*) $from_sql";
  warn "$me $sql (@param)" if $DEBUG;
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. " preparing $sql";
  $sth->execute(@param)         or die $sth->errstr. " executing $sql";

  $sth->fetchrow_arrayref->[0];

}

sub customer_tickets {
  my( $self, $custnum, $limit, $priority ) = @_;
  $limit ||= 0;

  my( $from_sql, @param) = $self->_from_customer( $custnum, $priority );
  my $sql = "
    SELECT Tickets.*,
           Queues.Name AS Queue,
           Users.Name  AS Owner,
           position(Tickets.Status in 'newopenstalledresolvedrejecteddeleted')
             AS svalue
           ". ( length($priority) ? ", ObjectCustomFieldValues.Content" : '' )."
      $from_sql
      ORDER BY svalue,
               Priority ". ( $priority_reverse ? 'ASC' : 'DESC' ). ",
               id DESC
      LIMIT $limit
  ";
  warn "$me $sql (@param)" if $DEBUG;
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. "preparing $sql";
  $sth->execute(@param)         or die $sth->errstr. "executing $sql";

  #munge column names???  #httemplate/view/cust_main/tickets.html has column
  #names that might not make sense now...
  $sth->fetchall_arrayref({});

}

sub comments_on_tickets {
  my ($self, $custnum, $limit, $time ) = @_;
  $limit ||= 0;

  my( $from_sql, @param) = $self->_from_customer( $custnum );
  my $sql = qq{
    SELECT transactions.*, Attachments.content, Tickets.subject
    FROM transactions
      JOIN Attachments ON( Attachments.transactionid = transactions.id )
      JOIN Tickets ON ( Tickets.id = transactions.objectid )
      JOIN Links  ON ( Tickets.id    = Links.LocalBase
                       AND Links.Base LIKE '%/ticket/' || Tickets.id )
       

    WHERE ( Status = 'new' OR Status = 'open' OR Status = 'stalled' )
      AND Target = 'freeside://freeside/cust_main/$custnum'
       AND transactions.type = 'Comment'
       AND transactions.created >= (SELECT TIMESTAMP WITH TIME ZONE 'epoch' + $time * INTERVAL '1 second')
     LIMIT $limit
  };
  cluck $sql if $DEBUG > 0;
  #AND created > 
  $dbh->selectall_arrayref( $sql, { Slice => {} } ) or die $dbh->errstr . " $sql";
}

sub _from_customer {
  my( $self, $custnum, $priority ) = @_;

  my @param = ();
  my $join = '';
  my $where = '';
  if ( defined($priority) ) {

    my $queue_sql = " ObjectCustomFields.ObjectId = ( SELECT id FROM Queues
                                                       WHERE Queues.Name = ? )
                      OR ( ? = '' AND ObjectCustomFields.ObjectId = 0 )";

    my $customfield_sql =
      "customfield = ( 
        SELECT CustomFields.Id FROM CustomFields
                  JOIN ObjectCustomFields
                    ON ( CustomFields.id = ObjectCustomFields.CustomField )
         WHERE LookupType = 'RT::Queue-RT::Ticket'
           AND Name = ?
           AND ( $queue_sql )
       )";

    push @param, $priority_field,
                 $priority_field_queue,
                 $priority_field_queue;

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
      unshift @param, $priority;

      $join = "JOIN ObjectCustomFieldValues
                 ON ( Tickets.id = ObjectCustomFieldValues.ObjectId )";
      
      $where = " AND Content = ?
                 AND ObjectCustomFieldValues.Disabled != 1
                 AND ObjectType = 'RT::Ticket'
                 AND $customfield_sql";

    } else {

      $where =
               "AND 0 = ( SELECT COUNT(*) FROM ObjectCustomFieldValues
                           WHERE ObjectId    = Tickets.id
                             AND ObjectType  = 'RT::Ticket'
                             AND $customfield_sql
                        )
               ";
    }

  }

  my $sql = "
    FROM Tickets
      JOIN Queues ON ( Tickets.Queue = Queues.id )
      JOIN Users  ON ( Tickets.Owner = Users.id  )
      JOIN Links  ON ( Tickets.id    = Links.LocalBase
                       AND Links.Base LIKE '%/ticket/' || Tickets.id )
      $join 

    WHERE ( ". join(' OR ', map "Status = '$_'", $self->statuses ). " )
      AND Target = 'freeside://freeside/cust_main/$custnum'
      $where
  ";

  ( $sql, @param );

}

sub statuses {
  #my $self = shift;
  my @statuses = grep { ! /^\s*$/ } $conf->config('cust_main-ticket_statuses');
  @statuses = (qw( new open stalled )) unless scalar(@statuses);
  @statuses;
}

sub href_customer_tickets {
  my( $self, $custnum ) = ( shift, shift );
  my( $priority, @statuses);
  if ( ref($_[0]) ) {
    my $opt = shift;
    $priority = $opt->{'priority'};
    @statuses = $opt->{'statuses'} ? @{$opt->{'statuses'}} : $self->statuses;
  } else {
    $priority = shift;
    @statuses = $self->statuses;
  }

  #my $href = $self->baseurl;

  #i snarfed this from an RT bookmarked search, then unescaped (some of) it with
  #perl -npe 's/%([0-9A-F]{2})/pack('C', hex($1))/eg;'

  #$href .= 
  my $href = 
    "Search/Results.html?Order=ASC&".
    "Query= MemberOf = 'freeside://freeside/cust_main/$custnum' ".
    #" AND ( Status = 'open'  OR Status = 'new'  OR Status = 'stalled' )"
    " AND ( ". join(' OR ', map "Status = '$_'", @statuses ). " ) "
  ;

  if ( defined($priority) && $field && $priority_field_queue ) {
    $href .= " AND Queue = '$priority_field_queue' ";
  }
  if ( defined($priority) && $field ) {
    $href .= " AND 'CF.$field' ";
    if ( $priority ) {
      $href .= "= '$priority' ";
    } else {
      $href .= "IS 'NULL' "; #this is "RTQL", not SQL
    }
  }

  #$href = 
  uri_escape($href);
  #eventually should unescape all of it...

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

  #$href =
  #uri_escape($href);

  $self->baseurl. $href;

}

sub href_new_ticket {
  my( $self, $custnum_or_cust_main, $requestors ) = @_;

  my( $custnum, $cust_main );
  if ( ref($custnum_or_cust_main) ) {
    $cust_main = $custnum_or_cust_main;
    $custnum = $cust_main->custnum;
  } else {
    $custnum = $custnum_or_cust_main;
    $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
  }
  my $queueid = $cust_main->agent->ticketing_queueid || $default_queueid;

  $self->baseurl.
  'Ticket/Create.html?'.
    "Queue=$queueid".
    "&new-MemberOf=freeside://freeside/cust_main/$custnum".
    ( $requestors ? '&Requestors='. uri_escape($requestors) : '' )
    ;
}

sub href_ticket {
  my($self, $ticketnum) = @_;
  $self->baseurl. 'Ticket/Display.html?id='.$ticketnum;
}

sub queues {
  my($self) = @_;

  my $sql = "SELECT id, Name FROM Queues WHERE Disabled = 0";
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. " preparing $sql";
  $sth->execute()               or die $sth->errstr. " executing $sql";

  map { $_->[0] => $_->[1] } @{ $sth->fetchall_arrayref([]) };

}

sub queue {
  my($self, $queueid) = @_;

  return '' unless $queueid;

  my $sql = "SELECT Name FROM Queues WHERE id = ?";
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. " preparing $sql";
  $sth->execute($queueid)       or die $sth->errstr. " executing $sql";

  my $rows = $sth->fetchrow_arrayref;
  $rows ? $rows->[0] : '';

}

sub baseurl {
  #my $self = shift;
  $external_url. '/';
}

sub _retrieve_single_value {
  my( $self, $sql ) = @_;

  warn "$me $sql" if $DEBUG;
  my $sth = $dbh->prepare($sql) or die $dbh->errstr. "preparing $sql";
  $sth->execute                 or die $sth->errstr. "executing $sql";

  my $arrayref = $sth->fetchrow_arrayref;
  $arrayref ? $arrayref->[0] : $arrayref;
}

sub transaction_creator {
  my( $self, $transaction_id ) = @_;

  my $sql = "SELECT Name FROM Transactions JOIN Users ON ".
            "Transactions.Creator=Users.id WHERE Transactions.id = ".
            $transaction_id;

  $self->_retrieve_single_value($sql);
}

sub transaction_ticketid {
  my( $self, $transaction_id ) = @_;

  my $sql = "SELECT ObjectId FROM Transactions WHERE Transactions.id = ".
            $transaction_id;
  
  $self->_retrieve_single_value($sql);
}

sub transaction_subject {
  my( $self, $transaction_id ) = @_;

  my $sql = "SELECT Subject FROM Transactions JOIN Tickets ON ObjectId=".
            "Tickets.id WHERE Transactions.id = ".  $transaction_id;
  
  $self->_retrieve_single_value($sql);
}

sub transaction_status {
  my( $self, $transaction_id ) = @_;

  my $sql = "SELECT Status FROM Transactions JOIN Tickets ON ObjectId=".
            "Tickets.id WHERE Transactions.id = ".  $transaction_id;
  
  $self->_retrieve_single_value($sql);
}

sub access_right {
  warn "WARNING: no access rights available w/ external RT";
  0;
}

sub create_ticket {
  return 'create_ticket unimplemented w/external RT (write something w/RT::Client::REST?)';
}

1;

