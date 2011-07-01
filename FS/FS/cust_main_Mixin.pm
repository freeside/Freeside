package FS::cust_main_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp qw( confess );
use FS::UID qw(dbh);
use FS::cust_main;
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( send_email generate_email );

$DEBUG = 0;
$me = '[FS::cust_main_Mixin]';

=head1 NAME

FS::cust_main_Mixin - Mixin class for records that contain fields from cust_main

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that contain fields from the cust_main table,
for example, from a JOINed search.  See httemplate/search/ for examples.

=head1 METHODS

=over 4

=cut

sub cust_unlinked_msg { '(unlinked)'; }
sub cust_linked { $_[0]->custnum; }

sub cust_main { 
  my $self = shift;
  $self->cust_linked ? qsearchs('cust_main', {custnum => $self->custnum}) : '';
}

=item display_custnum

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<name> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub display_custnum {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::display_custnum($self)
    : $self->cust_unlinked_msg;
}

=item name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<name> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::name($self)
    : $self->cust_unlinked_msg;
}

=item ship_name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_name> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_name($self)
    : $self->cust_unlinked_msg;
}

=item contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<contact> method, or "(unlinked)" if this object is not linked
to a customer.

=cut

sub contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::contact($self)
    : $self->cust_unlinked_msg;
}

=item ship_contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_contact> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_contact($self)
    : $self->cust_unlinked_msg;
}

=item country_full

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<country_full> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub country_full {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::country_full($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list_emailonly

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list_emailonly> method, or "(unlinked)" if this
object is not linked to a customer.

=cut

sub invoicing_list_emailonly {
  my $self = shift;
  warn "invoicing_list_email only called on $self, ".
       "custnum ". $self->custnum. "\n"
    if $DEBUG;
  $self->cust_linked
    ? FS::cust_main::invoicing_list_emailonly($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list_emailonly_scalar

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list_emailonly_scalar> method, or "(unlinked)" if
this object is not linked to a customer.

=cut

sub invoicing_list_emailonly_scalar {
  my $self = shift;
  warn "invoicing_list_emailonly called on $self, ".
       "custnum ". $self->custnum. "\n"
    if $DEBUG;
  $self->cust_linked
    ? FS::cust_main::invoicing_list_emailonly_scalar($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list> method, or "(unlinked)" if this object is not
linked to a customer.

Note: this method is read-only.

=cut

#read-only
sub invoicing_list {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::invoicing_list($self)
    : ();
}

=item status

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<status> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub cust_status {
  my $self = shift;
  return $self->cust_unlinked_msg unless $self->cust_linked;

  #FS::cust_main::status($self)
  #false laziness w/actual cust_main::status
  # (make sure FS::cust_main methods are called)
  for my $status (qw( prospect active inactive suspended cancelled )) {
    my $method = $status.'_sql';
    my $sql = FS::cust_main->$method();;
    my $numnum = ( $sql =~ s/cust_main\.custnum/?/g );
    my $sth = dbh->prepare("SELECT $sql") or die dbh->errstr;
    $sth->execute( ($self->custnum) x $numnum )
      or die "Error executing 'SELECT $sql': ". $sth->errstr;
    return $status if $sth->fetchrow_arrayref->[0];
  }
}

=item ucfirst_cust_status

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ucfirst_status> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ucfirst_cust_status {
  my $self = shift;
  $self->cust_linked
    ? ucfirst( $self->cust_status(@_) ) 
    : $self->cust_unlinked_msg;
}

=item cust_statuscolor

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<statuscol> method, or "000000" if this object is not linked to
a customer.

=cut

sub cust_statuscolor {
  my $self = shift;

  $self->cust_linked
    ? FS::cust_main::cust_statuscolor($self)
    : '000000';
}

=item prospect_sql

=item active_sql

=item inactive_sql

=item suspended_sql

=item cancelled_sql

Class methods that return SQL framents, equivalent to the corresponding
FS::cust_main method.

=cut

#      my \$self = shift;
#      \$self->cust_linked
#        ? FS::cust_main::${sub}_sql(\$self)
#        : '0';

foreach my $sub (qw( prospect active inactive suspended cancelled )) {
  eval "
    sub ${sub}_sql {
      confess 'cust_main_Mixin ${sub}_sql called with object' if ref(\$_[0]);
      'cust_main.custnum IS NOT NULL AND '. FS::cust_main->${sub}_sql();
    }
  ";
  die $@ if $@;
}

=item cust_search_sql

Returns a list of SQL WHERE fragments to search for parameters specified
in HASHREF.  Valid parameters are:

=over 4

=item agentnum

=item status

=item payby

=back

=cut

sub cust_search_sql {
  my($class, $param) = @_;

  if ( $DEBUG ) {
    warn "$me cust_search_sql called with params: \n".
         join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  }

  my @search = ();

  if ( $param->{'agentnum'} && $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.agentnum = $1";
  }

  #status (prospect active inactive suspended cancelled)
  if ( grep { $param->{'status'} eq $_ } FS::cust_main->statuses() ) {
    my $method = $param->{'status'}. '_sql';
    push @search, $class->$method();
  }

  #payby
  my @payby = ref($param->{'payby'})
                ? @{ $param->{'payby'} }
                : split(',', $param->{'payby'});
  @payby = grep /^([A-Z]{4})$/, @payby;
  if ( @payby ) {
    push @search, 'cust_main.payby IN ('. join(',', map "'$_'", @payby). ')';
  }

  #here is the agent virtualization
  push @search,
    $FS::CurrentUser::CurrentUser->agentnums_sql( 'table' => 'cust_main' );
  
  return @search;

}

=item email_search_result HASHREF

Emails a notice to the specified customers.  Customers without 
invoice email destinations will be skipped.

Parameters: 

=over 4

=item job

Queue job for status updates.  Required.

=item search

Hashref of params to the L<search()> method.  Required.

=item msgnum

Message template number (see L<FS::msg_template>).  Overrides all 
of the following options.

=item from

From: address

=item subject

Email Subject:

=item html_body

HTML body

=item text_body

Text body

=back

Returns an error message, or false for success.

If any messages fail to send, they will be queued as individual 
jobs which can be manually retried.  If the first ten messages 
in the job fail, the entire job will abort and return an error.

=cut

use Storable qw(thaw);
use MIME::Base64;
use Data::Dumper qw(Dumper);

sub email_search_result {
  my($class, $param) = @_;

  my $msgnum = $param->{msgnum};
  my $from = delete $param->{from};
  my $subject = delete $param->{subject};
  my $html_body = delete $param->{html_body};
  my $text_body = delete $param->{text_body};
  my $error = '';

  my $job = delete $param->{'job'}
    or die "email_search_result must run from the job queue.\n";
  
  my $msg_template;
  if ( $msgnum ) {
    $msg_template = qsearchs('msg_template', { msgnum => $msgnum } )
      or die "msgnum $msgnum not found\n";
  }

  my $sql_query = $class->search($param->{'search'});

  my $count_query   = delete($sql_query->{'count_query'});
  my $count_sth = dbh->prepare($count_query)
    or die "Error preparing $count_query: ". dbh->errstr;
  $count_sth->execute
    or die "Error executing $count_query: ". $count_sth->errstr;
  my $count_arrayref = $count_sth->fetchrow_arrayref;
  my $num_cust = $count_arrayref->[0];

  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
  my @retry_jobs = ();
  my $dups = 0;
  my $success = 0;
  my %sent_to = ();

  #eventually order+limit magic to reduce memory use?
  foreach my $obj ( qsearch($sql_query) ) {

    #progressbar first, so that the count is right
    $num++;
    if ( time - $min_sec > $last ) {
      my $error = $job->update_statustext(
        int( 100 * $num / $num_cust )
      );
      die $error if $error;
      $last = time;
    }

    my $cust_main = $obj->cust_main;
    my @message;
    if ( !$cust_main ) { 
      next; # unlinked object; nothing else we can do
    }

    if( $sent_to{$cust_main->custnum} ) {
      # avoid duplicates
      $dups++;
      next;
    }

    $sent_to{$cust_main->custnum} = 1;
    
    if ( $msg_template ) {
      # XXX add support for other context objects?
      # If we do that, handling of "duplicates" will 
      # have to be smarter.  Currently we limit to 
      # one message per custnum because they'd all
      # be identical.
      @message = $msg_template->prepare( 'cust_main' => $cust_main );
    }
    else {
      my @to = $cust_main->invoicing_list_emailonly;
      next if !@to;

      @message = (
        'from'      => $from,
        'to'        => \@to,
        'subject'   => $subject,
        'html_body' => $html_body,
        'text_body' => $text_body,
        'custnum'   => $cust_main->custnum,
      );
    } #if $msg_template

    $error = send_email( generate_email( @message ) );

    if($error) {
      # queue the sending of this message so that the user can see what we
      # tried to do, and retry if desired
      my $queue = new FS::queue {
        'job'        => 'FS::Misc::process_send_email',
        'custnum'    => $cust_main->custnum,
        'status'     => 'failed',
        'statustext' => $error,
      };
      $queue->insert(@message);
      push @retry_jobs, $queue;
    }
    else {
      $success++;
    }

    if($success == 0 and
        (scalar(@retry_jobs) > 10 or $num == $num_cust)
      ) {
      # 10 is arbitrary, but if we have enough failures, that's
      # probably a configuration or network problem, and we
      # abort the batch and run away screaming.
      # We NEVER do this if anything was successfully sent.
      $_->delete foreach (@retry_jobs);
      return "multiple failures: '$error'\n";
    }
  } # foreach $obj

  if(@retry_jobs) {
    # fail the job, but with a status message that makes it clear
    # something was sent.
    return "Sent $success, skipped $dups duplicate(s), failed ".scalar(@retry_jobs).". Failed attempts placed in job queue.\n";
  }

  return '';
}

sub process_email_search_result {
  my $job = shift;
  #warn "$me process_re_X $method for job $job\n" if $DEBUG;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  $param->{'job'} = $job;

  $param->{'search'} = thaw(decode_base64($param->{'search'}))
    or die "process_email_search_result requires search params.\n";

#  $param->{'payby'} = [ split(/\0/, $param->{'payby'}) ]
#    unless ref($param->{'payby'});

  my $table = $param->{'table'} 
    or die "process_email_search_result requires table.\n";

  eval "use FS::$table;";
  die "error loading FS::$table: $@\n" if $@;

  my $error = "FS::$table"->email_search_result( $param );
  die $error if $error;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

