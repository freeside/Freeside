package FS::queue;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use FS::Record qw( qsearch qsearchs dbh );
#use FS::queue;
use FS::queue_arg;
use FS::cust_svc;

@ISA = qw(FS::Record);
@EXPORT_OK = qw( joblisting );

=head1 NAME

FS::queue - Object methods for queue records

=head1 SYNOPSIS

  use FS::queue;

  $record = new FS::queue \%hash;
  $record = new FS::queue { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::queue object represents an queued job.  FS::queue inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item jobnum - primary key

=item job - fully-qualified subroutine name

=item status - job status

=item statustext - freeform text status message

=item _date - UNIX timestamp

=item svcnum - optional link to service (see L<FS::cust_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new job.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'queue'; }

=item insert [ ARGUMENT, ARGUMENT... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If any arguments are supplied, a queue_arg record for each argument is also
created (see L<FS::queue_arg>).

=cut

#false laziness w/part_export.pm
sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $arg ( @_ ) {
    my $queue_arg = new FS::queue_arg ( {
      'jobnum' => $self->jobnum,
      'arg'    => $arg,
    } );
    $error = $queue_arg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.  Any corresponding queue_arg records are
deleted as well

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @args = qsearch( 'queue_arg', { 'jobnum' => $self->jobnum } );

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $arg ( @args ) {
    $error = $arg->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid job.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error =
    $self->ut_numbern('jobnum')
    || $self->ut_anything('job')
    || $self->ut_numbern('_date')
    || $self->ut_enum('status',['', qw( new locked failed )])
    || $self->ut_textn('statustext')
    || $self->ut_numbern('svcnum')
  ;
  return $error if $error;

  $error = $self->ut_foreign_keyn('svcnum', 'cust_svc', 'svcnum');
  $self->svcnum('') if $error;

  $self->status('new') unless $self->status;
  $self->_date(time) unless $self->_date;

  ''; #no error
}

=item args

=cut

sub args {
  my $self = shift;
  map $_->arg, qsearch( 'queue_arg',
                        { 'jobnum' => $self->jobnum },
                        '',
                        'ORDER BY argnum'
                      );
}

=item cust_svc

Returns the FS::cust_svc object associated with this job, if any.

=cut

sub cust_svc {
  my $self = shift;
  qsearchs('cust_svc', { 'svcnum' => $self->svcnum } );
}

=item joblisting HASHREF

=cut

sub joblisting {
  my($hashref, $noactions) = @_;

  use Date::Format;
  use FS::CGI;

  my $html = FS::CGI::table(). <<END;
      <TR>
        <TH COLSPAN=2>Job</TH>
        <TH>Args</TH>
        <TH>Date</TH>
        <TH>Status</TH>
        <TH>Account</TH>
      </TR>
END

  my $p = FS::CGI::popurl(2);
  foreach my $queue ( sort { 
    $a->getfield('jobnum') <=> $b->getfield('jobnum')
  } qsearch( 'queue', $hashref ) ) {
    my $hashref = $queue->hashref;
    my $jobnum = $queue->jobnum;
    my $args = join(' ', $queue->args);
    my $date = time2str( "%a %b %e %T %Y", $queue->_date );
    my $status = $queue->status;
    $status .= ': '. $queue->statustext if $queue->statustext;
    if ( ! $noactions && $status =~ /^failed/ || $status =~ /^locked/ ) {
      $status .=
        qq! (&nbsp;<A HREF="$p/misc/queue.cgi?jobnum=$jobnum&action=new">retry</A>&nbsp;|!.
        qq!&nbsp;<A HREF="$p/misc/queue.cgi?jobnum=$jobnum&action=del">remove</A>&nbsp;)!;
    }
    my $cust_svc = $queue->cust_svc;
    my $account;
    if ( $cust_svc ) {
      my $table = $cust_svc->part_svc->svcdb;
      my $label = ( $cust_svc->label )[1];
      $account = qq!<A HREF="../view/$table.cgi?!. $queue->svcnum.
                 qq!">$label</A>!;
    } else {
      $account = '';
    }
    $html .= <<END;
      <TR>
        <TD>$jobnum</TD>
        <TD>$hashref->{job}</TD>
        <TD>$args</TD>
        <TD>$date</TD>
        <TD>$status</TD>
        <TD>$account</TD>
      </TR>
END

}

  $html .= '</TABLE>';

  $html;

}

=back

=head1 VERSION

$Id: queue.pm,v 1.7 2002-03-07 14:10:10 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

