package FS::cust_bill_event;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main_Mixin;
use FS::cust_bill;
use FS::part_bill_event;

@ISA = qw(FS::cust_main_Mixin FS::Record);

$DEBUG = 0;

=head1 NAME

FS::cust_bill_event - Object methods for cust_bill_event records

=head1 SYNOPSIS

  use FS::cust_bill_event;

  $record = new FS::cust_bill_event \%hash;
  $record = new FS::cust_bill_event { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_event object represents an complete invoice event.
FS::cust_bill_event inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item eventnum

Primary key

=item invnum

Invoice (see L<FS::cust_bill>)

=item eventpart

Event definition (see L<FS::part_bill_event>)

=item _date

Specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item status

Event status: B<done> or B<failed>

=item statustext

Additional status detail (i.e. error message)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new completed invoice event.  To add the compelted invoice event to
the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_event'; }

sub cust_linked { $_[0]->cust_main_custnum; } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum.
  ' (cust_bill.invnum '. $self->invnum. ')';
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid completed invoice event.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('eventnum')
    || $self->ut_number('invnum')
    || $self->ut_number('eventpart')
    || $self->ut_number('_date')
    || $self->ut_enum('status', [qw( done failed )])
    || $self->ut_anything('statustext')
  ;

  return "Unknown eventpart ". $self->eventpart
    unless my $part_bill_event =
      qsearchs( 'part_bill_event' ,{ 'eventpart' => $self->eventpart } );

  return "Unknown invnum ". $self->invnum
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  $self->SUPER::check;
}

=item part_bill_event

Returns the invoice event definition (see L<FS::part_bill_event>) for this
completed invoice event.

=cut

sub part_bill_event {
  my $self = shift;
  qsearchs( 'part_bill_event', { 'eventpart' => $self->eventpart } );
}

=item cust_bill

Returns the invoice (see L<FS::cust_bill>) for this completed invoice event.

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
}

=item retry

Changes the status of this event from B<done> to B<failed>, allowing it to be
retried.

=cut

sub retry {
  my $self = shift;
  return '' unless $self->status eq 'done';
  my $old = ref($self)->new( { $self->hash } );
  $self->status('failed');
  $self->replace($old);
}

=item retryable

Changes the statustext of this event to B<retriable>, rendering it 
retriable (should retry be called).

=cut

sub retriable {
  my $self = shift;
  return '' unless $self->status eq 'done';
  my $old = ref($self)->new( { $self->hash } );
  $self->statustext('retriable');
  $self->replace($old);
}

=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Valid parameters are

=over 4

=item agentnum

=item beginning

An epoch date setting a lower bound for _date values

=item ending

An epoch date setting a upper bound for _date values

=item failed

Limits the search to failed events if true

=item payby

Requires that the search be JOIN'd to part_bill_event # Bug?

=item invnum 

=item currentuser

Specifies the user for agent virtualization

=back

=cut

sub search_sql_where {
  my ($class, $params) = @_;
  my @search = ();

  push @search, "agentnum = ". $params->{agentnum} if $params->{agentnum};

  push @search, "cust_bill_event._date >= ". $params->{beginning}
    if $params->{beginning};
  push @search, "cust_bill_event._date <= ". $params->{ending}
    if $params->{ending};

  push @search, "statustext != ''",
                "statustext IS NOT NULL",
                "statustext != 'N/A'"
    if $params->{failed};

  push @search, "part_bill_event.payby = '". $params->{payby}. "'"
    if $params->{payby};

  push @search, "cust_bill_event.invnum = '". $params->{invnum}. "'"
    if $params->{invnum};

  my $currentuser = $params->{currentuser} || $params->{CurrentUser};
  if ($currentuser) {
    my $access_user = qsearchs('access_user', { username => $currentuser });
    if ($access_user) {
      push @search, $access_user->agentnums_sql;
    }else{
      push @search, "1=0";
    }
  }else{
    push @search, $FS::CurrentUser::CurrentUser->agentnums_sql;
  }

  join(' AND ', @search );

}

=back

=head1 SUBROUTINES

=over 4

=item reprint

=cut

sub process_reprint {
  process_re_X('print', @_);
}

=item reemail

=cut

sub process_reemail {
  process_re_X('email', @_);
}

=item refax

=cut

sub process_refax {
  process_re_X('fax', @_);
}

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_re_X {
  my( $method, $job ) = ( shift, shift );

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  re_X(
    $method,
    $param,
    $job,
  );

}

sub re_X {
  my($method, $param, $job) = @_;

  my $where = FS::cust_bill_event->search_sql_where($param);
  $where = " WHERE plan LIKE 'send%'". ( $where ? " AND $where" : "" );

  my $from = 'LEFT JOIN part_bill_event USING ( eventpart )'.
             'LEFT JOIN cust_bill       USING ( invnum )'.
             'LEFT JOIN cust_main       USING ( custnum )';

  my @cust_bill_event = qsearch( 'cust_bill_event', {}, '', $where, '', $from );

  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
  foreach my $cust_bill_event ( @cust_bill_event ) {

    $cust_bill_event->cust_bill->$method(
      $cust_bill_event->part_bill_event->templatename
    );

    if ( $job ) { #progressbar foo
      $num++;
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $num / scalar(@cust_bill_event) )
        );
        die $error if $error;
        $last = time;
      }
    }

  }

  #this doesn't work, but it would be nice
  #if ( $job ) { #progressbar foo
  #  my $error = $job->update_statustext(
  #    scalar(@cust_bill_event). " invoices re-${method}ed"
  #  );
  #  die $error if $error;
  #}

}

=back

=head1 BUGS

Far too early in the morning.

=head1 SEE ALSO

L<FS::part_bill_event>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

