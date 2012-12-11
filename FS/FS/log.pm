package FS::log;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::UID qw( dbh driver_name );
use FS::log_context;

=head1 NAME

FS::log - Object methods for log records

=head1 SYNOPSIS

  use FS::log;

  $record = new FS::log \%hash;
  $record = new FS::log { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::log object represents a log entry.  FS::log inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item lognum - primary key

=item _date - Unix timestamp

=item agentnum - L<FS::agent> to which the log pertains.  If it involves a 
specific customer, package, service, invoice, or other agent-specific object,
this will be set to that agentnum.

=item tablename - table name to which the log pertains, if any.

=item tablenum - foreign key to that table.

=item level - log level: 'debug', 'info', 'notice', 'warning', 'error', 
'critical', 'alert', 'emergency'.

=item message - contents of the log entry

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new log entry.  Use FS::Log instead of calling this directly, 
please.

=cut

sub table { 'log'; }

=item insert [ CONTEXT... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

CONTEXT may be a list of context tags to attach to this record.

=cut

sub insert {
  # not using process_o2m for this, because we don't have a web interface
  my $self = shift;
  my $error = $self->SUPER::insert;
  return $error if $error;
  foreach ( @_ ) {
    my $context = FS::log_context->new({
        'lognum'  => $self->lognum,
        'context' => $_
    });
    $error = $context->insert;
    return $error if $error;
  }
  '';
}

# the insert method can be inherited from FS::Record

sub delete  { die "Log entries can't be modified." };

sub replace { die "Log entries can't be modified." };

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('lognum')
    || $self->ut_number('_date')
    || $self->ut_numbern('agentnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_textn('tablename')
    || $self->ut_numbern('tablenum')
    || $self->ut_number('level')
    || $self->ut_text('message')
  ;
  return $error if $error;

  if ( my $tablename = $self->tablename ) {
    my $dbdef_table = dbdef->table($tablename)
      or return "tablename '$tablename' does not exist";
    $error = $self->ut_foreign_key('tablenum',
                                   $tablename,
                                   $dbdef_table->primary_key);
    return $error if $error;
  }

  $self->SUPER::check;
}

=item context

Returns the context for this log entry, as an array, from least to most
specific.

=cut

sub context {
  my $self = shift;
  map { $_->context } qsearch({
      table     => 'log_context',
      hashref   => { lognum => $self->lognum },
      order_by  => 'ORDER BY logcontextnum ASC',
  });
}

=back

=head1 CLASS METHODS

=over 4

=item search HASHREF

Returns a qsearch hash expression to search for parameters specified in 
HASHREF.  Valid parameters are:

=over 4

=item agentnum

=item date - arrayref of start and end date

=item level - either a specific level, or an arrayref of min and max level

=item context - a context string that the log entry must have.  This may 
change in the future to allow searching for combinations of context strings.

=item object - any database object, to find log entries related to it.

=item tablename, tablenum - alternate way of specifying 'object'.

=item custnum - a customer number, to find log entries related to the customer
or any of their subordinate objects (invoices, packages, etc.).

=item message - a text string to search in messages.  The search will be 
a case-insensitive LIKE with % appended at both ends.

=back

=cut

# used for custnum search: all tables with custnums
my @table_stubs;

sub _setup_table_stubs {
  foreach my $table (
    qw( 
    contact
    cust_attachment
    cust_bill
    cust_credit
    cust_location
    cust_main
    cust_main_exemption
    cust_main_note
    cust_msg
    cust_pay
    cust_pay_batch
    cust_pay_pending
    cust_pay_void
    cust_pkg
    cust_refund
    cust_statement
    cust_tag
    cust_tax_adjustment
    cust_tax_exempt
    did_order_item
    qual
    queue ) )
  {
    my $pkey = dbdef->table($table)->primary_key;
    push @table_stubs,
      "log.tablename = '$table' AND ".
      "EXISTS(SELECT 1 FROM $table WHERE log.tablenum = $table.$pkey AND ".
      "$table.custnum = "; # needs a closing )
  }
  # plus this case
  push @table_stubs,
      "(log.tablename LIKE 'svc_%' OR log.tablename = 'cust_svc') AND ".
      "EXISTS(SELECT 1 FROM cust_svc JOIN cust_pkg USING (svcnum) WHERE ".
      "cust_pkg.custnum = "; # needs a closing )
}

sub search {
  my ($class, $params) = @_;
  my @where;

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ ) {
    push @where,
      "log.agentnum = $1";
  }

  ##
  # parse custnum
  ##

  if ( $params->{'custnum'} =~ /^(\d+)$/ ) {
    _setup_table_stubs() unless @table_stubs;
    my $custnum = $1;
    my @orwhere = map { "( $_ $custnum) )" } @table_stubs;
    push @where, join(' OR ', @orwhere);
  }

  ##
  # parse level
  ##

  if ( ref $params->{'level'} eq 'ARRAY' ) {
    my ($min, $max) = @{ $params->{'level'} };
    if ( $min =~ /^\d+$/ ) {
      push @where, "log.level >= $min";
    }
    if ( $max =~ /^\d+$/ ) {
      push @where, "log.level <= $max";
    }
  } elsif ( $params->{'level'} =~ /^(\d+)$/ ) {
    push @where, "log.level = $1";
  }

  ##
  # parse date
  ##

  if ( ref $params->{'date'} eq 'ARRAY' ) {
    my ($beg, $end) = @{ $params->{'date'} };
    if ( $beg =~ /^\d+$/ ) {
      push @where, "log._date >= $beg";
    }
    if ( $end =~ /^\d+$/ ) {
      push @where, "log._date <= $end";
    }
  }

  ##
  # parse object
  ##

  if ( $params->{'object'} and $params->{'object'}->isa('FS::Record') ) {
    my $table = $params->{'object'}->table;
    my $pkey = dbdef->table($table)->primary_key;
    my $tablenum = $params->{'object'}->get($pkey);
    if ( $table and $tablenum ) {
      push @where, "log.tablename = '$table'", "log.tablenum = $tablenum";
    }
  } elsif ( $params->{'tablename'} =~ /^(\w+)$/ ) {
    my $table = $1;
    if ( $params->{'tablenum'} =~ /^(\d+)$/ ) {
      push @where, "log.tablename = '$table'", "log.tablenum = $1";
    }
  }

  ##
  # parse message
  ##

  if ( $params->{'message'} ) { # can be anything, really, so escape it
    my $quoted_message = dbh->quote('%' . $params->{'message'} . '%');
    my $op = (driver_name eq 'Pg' ? 'ILIKE' : 'LIKE');
    push @where, "log.message $op $quoted_message";
  }

  ##
  # parse context
  ##

  if ( $params->{'context'} ) {
    my $quoted = dbh->quote($params->{'context'});
    push @where, 
      "EXISTS(SELECT 1 FROM log_context WHERE log.lognum = log_context.lognum ".
      "AND log_context.context = $quoted)";
  }

  # agent virtualization
  my $access_user = $FS::CurrentUser::CurrentUser;
  push @where, $access_user->agentnums_sql(
    table => 'log',
    viewall_right => 'Configuration',
    null => 1,
  );

  # put it together
  my $extra_sql = '';
  $extra_sql .= 'WHERE ' . join(' AND ', @where) if @where;
  my $count_query = 'SELECT COUNT(*) FROM log '.$extra_sql;
  my $sql_query = {
    'table'         => 'log',
    'hashref'       => {},
    'select'        => 'log.*',
    'extra_sql'     => $extra_sql,
    'count_query'   => $count_query,
    'order_by'      => 'ORDER BY _date ASC',
    #addl_from, not needed
  };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

