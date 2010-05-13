package FS::queue;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG $conf $jobnums);
use Exporter;
use MIME::Base64;
use Storable qw( nfreeze thaw );
use FS::UID qw(myconnect);
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh );
#use FS::queue;
use FS::queue_arg;
use FS::queue_depend;
use FS::cust_svc;
use FS::CGI qw (rooturl);

@ISA = qw(FS::Record);
@EXPORT_OK = qw( joblisting );

$DEBUG = 0;

$FS::UID::callback{'FS::queue'} = sub {
  $conf = new FS::Conf;
};

$jobnums = '';

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

=item jobnum

Primary key

=item job

Fully-qualified subroutine name

=item status

Job status (new, locked, or failed)

=item statustext

Freeform text status message

=item _date

UNIX timestamp

=item svcnum

Optional link to service (see L<FS::cust_svc>).

=item custnum

Optional link to customer (see L<FS::cust_main>).

=item secure

Secure flag, 'Y' indicates that when using encryption, the job needs to be
run on a machine with the private key.

=cut

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new job.  To add the job to the database, see L<"insert">.

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
  my( $self, @args ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my %args = ();
  { 
    no warnings "misc";
    %args = @args;
  }

  $self->custnum( $args{'custnum'} ) if $args{'custnum'};

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $arg ( @args ) {
    my $freeze = ref($arg) ? 'Y' : '';
    my $queue_arg = new FS::queue_arg ( {
      'jobnum' => $self->jobnum,
      'frozen' => $freeze,
      'arg'    => $freeze ? encode_base64(nfreeze($arg)) : $arg,# always freeze?
    } );
    $error = $queue_arg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $jobnums ) {
    warn "jobnums global is active: $jobnums\n" if $DEBUG;
    push @$jobnums, $self->jobnum;
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

  my @del = qsearch( 'queue_arg', { 'jobnum' => $self->jobnum } );
  push @del, qsearch( 'queue_depend', { 'depend_jobnum' => $self->jobnum } );

  my $reportname = '';
  if ( $self->status =~/^done/ ) {
    my $dropstring = rooturl(). '/misc/queued_report\?report=';
    if ($self->statustext =~ /.*$dropstring([.\w]+)\>/) {
      $reportname = "$FS::UID::cache_dir/cache.$FS::UID::datasrc/report.$1";
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $del ( @del ) {
    $error = $del->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  
  unlink $reportname if $reportname;

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
    || $self->ut_enum('status',['', qw( new locked failed done )])
    || $self->ut_anything('statustext')
    || $self->ut_numbern('svcnum')
  ;
  return $error if $error;

  $error = $self->ut_foreign_keyn('svcnum', 'cust_svc', 'svcnum');
  $self->svcnum('') if $error;

  $self->status('new') unless $self->status;
  $self->_date(time) unless $self->_date;

  $self->SUPER::check;
}

=item args

Returns a list of the arguments associated with this job.

=cut

sub args {
  my $self = shift;
  map { $_->frozen ? thaw(decode_base64($_->arg)) : $_->arg }
    qsearch( 'queue_arg',
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

=item queue_depend

Returns the FS::queue_depend objects associated with this job, if any.
(Dependancies that must complete before this job can be run).

=cut

sub queue_depend {
  my $self = shift;
  qsearch('queue_depend', { 'jobnum' => $self->jobnum } );
}

=item depend_insert OTHER_JOBNUM

Inserts a dependancy for this job - it will not be run until the other job
specified completes.  If there is an error, returns the error, otherwise
returns false.

When using job dependancies, you should wrap the insertion of all relevant jobs
in a database transaction.  

=cut

sub depend_insert {
  my($self, $other_jobnum) = @_;
  my $queue_depend = new FS::queue_depend ( {
    'jobnum'        => $self->jobnum,
    'depend_jobnum' => $other_jobnum,
  } );
  $queue_depend->insert;
}

=item queue_depended

Returns the FS::queue_depend objects that associate other jobs with this job,
if any.  (The jobs that are waiting for this job to complete before they can
run).

=cut

sub queue_depended {
  my $self = shift;
  qsearch('queue_depend', { 'depend_jobnum' => $self->jobnum } );
}

=item depended_delete

Deletes the other queued jobs (FS::queue objects) that are waiting for this
job, if any.  If there is an error, returns the error, otherwise returns false.

=cut

sub depended_delete {
  my $self = shift;
  my $error;
  foreach my $job (
    map { qsearchs('queue', { 'jobnum' => $_->jobnum } ) } $self->queue_depended
  ) {
    $error = $job->depended_delete;
    return $error if $error;
    $error = $job->delete;
    return $error if $error
  }
}

=item update_statustext VALUE

Updates the statustext value of this job to supplied value, in the database.
If there is an error, returns the error, otherwise returns false.

=cut

use vars qw($_update_statustext_dbh);
sub update_statustext {
  my( $self, $statustext ) = @_;
  return '' if $statustext eq $self->statustext;
  warn "updating statustext for $self to $statustext" if $DEBUG;

  $_update_statustext_dbh ||= myconnect;

  my $sth = $_update_statustext_dbh->prepare(
    'UPDATE queue set statustext = ? WHERE jobnum = ?'
  ) or return $_update_statustext_dbh->errstr;

  $sth->execute($statustext, $self->jobnum) or return $sth->errstr;
  $_update_statustext_dbh->commit or die $_update_statustext_dbh->errstr;
  $self->statustext($statustext);
  '';

  #my $new = new FS::queue { $self->hash };
  #$new->statustext($statustext);
  #my $error = $new->replace($self);
  #return $error if $error;
  #$self->statustext($statustext);
  #'';
}

=back

=head1 SUBROUTINES

=over 4

=item joblisting HASHREF NOACTIONS

=cut

sub joblisting {
  my($hashref, $noactions) = @_;

  use Date::Format;
  use HTML::Entities;
  use FS::CGI;

  my @queue = qsearch( 'queue', $hashref );
  return '' unless scalar(@queue);

  my $p = FS::CGI::popurl(2);

  my $html = qq!<FORM ACTION="$p/misc/queue.cgi" METHOD="POST">!.
             FS::CGI::table(). <<END;
      <TR>
        <TH COLSPAN=2>Job</TH>
        <TH>Args</TH>
        <TH>Date</TH>
        <TH>Status</TH>
END
  $html .= '<TH>Account</TH>' unless $hashref->{svcnum};
  $html .= '</TR>';

  my $dangerous = $conf->exists('queue_dangerous_controls');

  my $areboxes = 0;

  foreach my $queue ( sort { 
    $a->getfield('jobnum') <=> $b->getfield('jobnum')
  } @queue ) {
    my $queue_hashref = $queue->hashref;
    my $jobnum = $queue->jobnum;

    my $args;
    if ( $dangerous || $queue->job !~ /^FS::part_export::/ || !$noactions ) {
      $args = encode_entities( join(' ', $queue->args) );
    } else {
      $args = '';
    }

    my $date = time2str( "%a %b %e %T %Y", $queue->_date );
    my $status = $queue->status;
    $status .= ': '. $queue->statustext if $queue->statustext;
    my @queue_depend = $queue->queue_depend;
    $status .= ' (waiting for '.
               join(', ', map { $_->depend_jobnum } @queue_depend ). 
               ')'
      if @queue_depend;
    my $changable = $dangerous
         || ( ! $noactions && $status =~ /^failed/ || $status =~ /^locked/ );
    if ( $changable ) {
      $status .=
        qq! (&nbsp;<A HREF="$p/misc/queue.cgi?jobnum=$jobnum&action=new">retry</A>&nbsp;|!.
        qq!&nbsp;<A HREF="$p/misc/queue.cgi?jobnum=$jobnum&action=del">remove</A>&nbsp;)!;
    }
    my $cust_svc = $queue->cust_svc;

    $html .= <<END;
      <TR>
        <TD>$jobnum</TD>
        <TD>$queue_hashref->{job}</TD>
        <TD>$args</TD>
        <TD>$date</TD>
        <TD>$status</TD>
END

    unless ( $hashref->{svcnum} ) {
      my $account;
      if ( $cust_svc ) {
        my $table = $cust_svc->part_svc->svcdb;
        my $label = ( $cust_svc->label )[1];
        $account = qq!<A HREF="../view/$table.cgi?!. $queue->svcnum.
                   qq!">$label</A>!;
      } else {
        $account = '';
      }
      $html .= "<TD>$account</TD>";
    }

    if ( $changable ) {
      $areboxes=1;
      $html .=
        qq!<TD><INPUT NAME="jobnum$jobnum" TYPE="checkbox" VALUE="1"></TD>!;

    }

    $html .= '</TR>';

}

  $html .= '</TABLE>';

  if ( $areboxes ) {
    $html .= '<BR><INPUT TYPE="submit" NAME="action" VALUE="retry selected">'.
             '<INPUT TYPE="submit" NAME="action" VALUE="remove selected"><BR>';
  }

  $html;

}

=back

=head1 BUGS

$jobnums global

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

