package FS::cust_main_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp qw( confess carp cluck );
use FS::UID qw(dbh);
use FS::cust_main;
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( send_email generate_email );
use HTML::Entities;

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
  cluck ref($self). '->cust_main called' if $DEBUG;
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
  if ( $self->locationnum ) {  # cust_pkg has this
    my $location = FS::cust_location->by_key($self->locationnum);
    $location ? $location->country_full : '';
  } elsif ( $self->cust_linked ) {
    $self->cust_main->bill_country_full;
  }
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
  my $cust_main = $self->cust_main;
  return $self->cust_unlinked_msg unless $cust_main;
  return $cust_main->cust_status;
}

=item ucfirst_cust_status

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ucfirst_status> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ucfirst_cust_status {
  carp "ucfirst_cust_status deprecated, use cust_status_label";
  local($FS::cust_main::ucfirst_nowarn) = 1;
  my $self = shift;
  $self->cust_linked
    ? ucfirst( $self->cust_status(@_) ) 
    : $self->cust_unlinked_msg;
}

=item cust_status_label

=cut

sub cust_status_label {
  my $self = shift;

  $self->cust_linked
    ? FS::cust_main::cust_status_label($self)
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

=item to_contact_classnum

The customer contact class (or classes, as a comma-separated list) to send
the message to. If unspecified, will be sent to any contacts that are marked
as invoice destinations (the equivalent of specifying 'invoice').

=back

Returns an error message, or false for success.

If any messages fail to send, they will be queued as individual 
jobs which can be manually retried.  If the first ten messages 
in the job fail, the entire job will abort and return an error.

=cut

use Storable qw(thaw);
use MIME::Base64;
use Data::Dumper qw(Dumper);
use Digest::SHA qw(sha1); # for duplicate checking

sub email_search_result {
  my($class, $param) = @_;

  my $conf = FS::Conf->new;
  my $send_to_domain = $conf->config('email-to-voice_domain');

  my $msgnum = $param->{msgnum};
  my $from = delete $param->{from};
  my $subject = delete $param->{subject};
  my $html_body = delete $param->{html_body};
  my $text_body = delete $param->{text_body};
  my $to_contact_classnum = delete $param->{to_contact_classnum};
  my $emailtovoice_name = delete $param->{emailtovoice_contact};

  my $error = '';

  my $to = $emailtovoice_name . '@' . $send_to_domain unless !$emailtovoice_name;

  my $job = delete $param->{'job'}
    or die "email_search_result must run from the job queue.\n";
  
  my $msg_template;
  if ( $msgnum ) {
    $msg_template = qsearchs('msg_template', { msgnum => $msgnum } )
      or die "msgnum $msgnum not found\n";
  } else {
    $msg_template = FS::msg_template->new({
        from_addr => $from,
        msgname   => $subject, # maybe a timestamp also?
        disabled  => 'D', # 'D'raft
        # msgclass, maybe
    });
    $error = $msg_template->insert(
      subject => $subject,
      body    => $html_body,
    );
    return "$error (when creating draft template)" if $error;
  }

  my $sql_query = $class->search($param->{'search'});
  $sql_query->{'select'} = $sql_query->{'table'} . '.*';

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

  if ( !$msg_template ) {
    die "email_search_result now requires a msg_template";
  }

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
    if ( !$cust_main ) { 
      next; # unlinked object; nothing else we can do
    }

my %to = {};
if ($to) { $to{'to'} = $to; }

    my $cust_msg = $msg_template->prepare(
      'cust_main' => $cust_main,
      'object'    => $obj,
      'to_contact_classnum' => $to_contact_classnum,
      %to,
    );

    # For non-cust_main searches, we avoid duplicates based on message
    # body text.
    my $unique = $cust_main->custnum;
    $unique .= sha1($cust_msg->text_body) if $class ne 'FS::cust_main';
    if( $sent_to{$unique} ) {
      # avoid duplicates
      $dups++;
      next;
    }

    $sent_to{$unique} = 1;
    
    $error = $cust_msg->send;

    if($error) {
      # queue the sending of this message so that the user can see what we
      # tried to do, and retry if desired
      # (note the cust_msg itself also now has a status of 'failed'; that's 
      # fine, as it will get its status reset if we retry the job)
      my $queue = new FS::queue {
        'job'        => 'FS::cust_msg::process_send',
        'custnum'    => $cust_main->custnum,
        'status'     => 'failed',
        'statustext' => $error,
      };
      $queue->insert($cust_msg->custmsgnum);
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

  # if the message template was created as "draft", change its status to
  # "completed"
  if ($msg_template->disabled eq 'D') {
    $msg_template->set('disabled' => 'C');
    my $error = $msg_template->replace;
    warn "$error (setting draft message template status)" if $error;
  }

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

  my $param = shift;
  warn Dumper($param) if $DEBUG;

  $param->{'job'} = $job;

  $param->{'search'} = thaw(decode_base64($param->{'search'}))
    or die "process_email_search_result requires search params.\n";

  my $table = $param->{'table'} 
    or die "process_email_search_result requires table.\n";

  eval "use FS::$table;";
  die "error loading FS::$table: $@\n" if $@;

  my $error = "FS::$table"->email_search_result( $param );
  dbh->commit; # save failed jobs before rethrowing the error
  die $error if $error;

}

=item conf

Returns a configuration handle (L<FS::Conf>) set to the customer's locale, 
if they have one.  If not, returns an FS::Conf with no locale.

=cut

sub conf {
  my $self = shift;
  return $self->{_conf} if (ref $self and $self->{_conf});
  my $cust_main = $self->cust_main;
  my $conf = new FS::Conf { 
    'locale' => ($cust_main ? $cust_main->locale : '')
  };
  $self->{_conf} = $conf if ref $self;
  return $conf;
}

=item mt TEXT [, ARGS ]

Localizes a text string (see L<Locale::Maketext>) for the customer's locale,
if they have one.

=cut

sub mt {
  my $self = shift;
  return $self->{_lh}->maketext(@_) if (ref $self and $self->{_lh});
  my $cust_main = $self->cust_main;
  my $locale = $cust_main ? $cust_main->locale : '';
  my $lh = FS::L10N->get_handle($locale);
  $self->{_lh} = $lh if ref $self;
  return $lh->maketext(@_);
}

=item time2str_local FORMAT, TIME[, ESCAPE]

Localizes a date (see L<Date::Language>) for the customer's locale.

FORMAT can be a L<Date::Format> string, or one of these special words:

- "short": the value of the "date_format" config setting for the customer's 
  locale, defaulting to "%x".
- "rdate": the same as "short" except that the default has a four-digit year.
- "long": the value of the "date_format_long" config setting for the 
  customer's locale, defaulting to "%b %o, %Y".

ESCAPE, if specified, is one of "latex" or "html", and will escape non-ASCII
characters and convert spaces to nonbreaking spaces.

=cut

sub time2str_local {
  # renamed so that we don't have to change every single reference to 
  # time2str everywhere
  my $self = shift;
  my ($format, $time, $escape) = @_;
  return '' unless $time > 0; # work around time2str's traditional stupidity

  $self->{_date_format} ||= {};
  if (!exists($self->{_dh})) {
    my $cust_main = $self->cust_main;
    my $locale = $cust_main->locale  if $cust_main;
    $locale ||= 'en_US';
    my %info = FS::Locales->locale_info($locale);
    my $dh = eval { Date::Language->new($info{'name'}) } ||
             Date::Language->new(); # fall back to English
    $self->{_dh} = $dh;
  }

  if ($format eq 'short') {
    $format = $self->{_date_format}->{short}
            ||= $self->conf->config('date_format') || '%x';
  } elsif ($format eq 'rdate') {
    $format = $self->{_date_format}->{rdate}
            ||= $self->conf->config('date_format') || '%m/%d/%Y';
  } elsif ($format eq 'long') {
    $format = $self->{_date_format}->{long}
            ||= $self->conf->config('date_format_long') || '%b %o, %Y';
  }

  # actually render the date
  my $string = $self->{_dh}->time2str($format, $time);

  if ($escape) {
    if ($escape eq 'html') {
      $string = encode_entities($string);
      $string =~ s/ +/&nbsp;/g;
    } elsif ($escape eq 'latex') { # just do nbsp's here
      $string =~ s/ +/~/g;
    }
  }
  
  $string;
}

=item unsuspend_balance

If conf I<unsuspend_balance> is set and customer's current balance is
beneath the set threshold, unsuspends customer packages.

=cut

sub unsuspend_balance {
  my $self = shift;
  my $cust_main = $self->cust_main;
  my $conf = $self->conf;
  my $setting = $conf->config('unsuspend_balance') or return;
  my $maxbalance;
  if ($setting eq 'Zero') {
    $maxbalance = 0;

  # kind of a pain to load/check all cust_bill instead of just open ones,
  # but if for some reason payment gets applied to later bills before
  # earlier ones, we still want to consider the later ones as allowable balance
  } elsif ($setting eq 'Latest invoice charges') {
    my @cust_bill = $cust_main->cust_bill();
    my $cust_bill = $cust_bill[-1]; #always want the most recent one
    if ($cust_bill) {
      $maxbalance = $cust_bill->charged || 0;
    } else {
      $maxbalance = 0;
    }
  } elsif ($setting eq 'Charges not past due') {
    my $now = time;
    $maxbalance = 0;
    foreach my $cust_bill ($cust_main->cust_bill()) {
      next unless $now <= ($cust_bill->due_date || $cust_bill->_date);
      $maxbalance += $cust_bill->charged || 0;
    }
  } elsif (length($setting)) {
    warn "Unrecognized unsuspend_balance setting $setting";
    return;
  } else {
    return;
  }
  my $balance = $cust_main->balance || 0;
  if ($balance <= $maxbalance) {
    my @errors = $cust_main->unsuspend;
    # side-fx with nested transactions?  upstack rolls back?
    warn "WARNING:Errors unsuspending customer ". $cust_main->custnum. ": ".
         join(' / ', @errors)
      if @errors;
  }
  return;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

