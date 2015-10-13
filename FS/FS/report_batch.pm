package FS::report_batch;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs dbdef );
use FS::msg_template;
use FS::cust_main;
use FS::Misc::DateTime qw(parse_datetime);
use FS::Mason qw(mason_interps);
use URI::Escape;
use HTML::Defang;

our $DEBUG = 0;

=head1 NAME

FS::report_batch - Object methods for report_batch records

=head1 SYNOPSIS

  use FS::report_batch;

  $record = new FS::report_batch \%hash;
  $record = new FS::report_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::report_batch object represents an order to send a batch of reports to
their respective customers or other contacts.  FS::report_batch inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item reportbatchnum

primary key

=item reportname

The name of the report, which will be the same as the file name (minus any
directory names). There's an enumerated set of these; you can't use just any
report.

=item send_date

The date the report was sent.

=item agentnum

The agentnum to limit the report to, if any.

=item sdate

The start date of the report period.

=item edate

The end date of the report period.

=item usernum

The user who ordered the report.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new report batch.  To add the record to the database, see L<"insert">.

=cut

sub table { 'report_batch'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('reportbatchnum')
    || $self->ut_text('reportname')
    || $self->ut_numbern('agentnum')
    || $self->ut_numbern('sdate')
    || $self->ut_numbern('edate')
    || $self->ut_numbern('usernum')
  ;
  return $error if $error;

  $self->set('send_date', time);

  $self->SUPER::check;
}

=back

=head1 SUBROUTINES

=over 4

=item process_send_report JOB, PARAMS

Takes a hash of PARAMS, determines all contacts who need to receive a report,
and sends it to them. On completion, creates and stores a report_batch record.
JOB is a queue job to receive status messages.

PARAMS can include:

- reportname: the name of the report (listed in the C<%sendable_reports> hash).
Required.
- msgnum: the L<FS::msg_template> to use for this report. Currently the
content of the template is ignored, but the subject line and From/Bcc addresses
are still used. Required.
- agentnum: the agent to limit the report to.
- beginning, ending: the date range to run the report, as human-readable 
dates (I<not> unix timestamps).

=cut

# trying to keep this data-driven, with parameters that tell how the report is
# to be handled rather than callbacks.
# - path: where under the document root the report is located
# - domain: which table to query for objects on which the report is run.
#   Each record in that table produces one report.
# - cust_main: the method on that object that returns its linked customer (to
#   which the report will be sent). If the table has a 'custnum' field, this
#   can be omitted.
our %sendable_reports = (
  'sales_commission_pkg' => {
    'name'      => 'Sales commission per package',
    'path'      => '/search/sales_commission_pkg.html',
    'domain'    => 'sales',
    'cust_main' => 'sales_cust_main',
  },
);

sub process_send_report {
  my $job = shift;
  my $param = shift;

  my $msgnum = $param->{'msgnum'};
  my $template = FS::msg_template->by_key($msgnum)
    or die "msg_template $msgnum not found\n";

  my $reportname = $param->{'reportname'};
  my $info = $sendable_reports{$reportname}
    or die "don't know how to send report '$reportname'\n";

  # the most important thing: which report is it?
  my $path = $info->{'path'};

  # find all targets for the report:
  # - those matching the agentnum if there is one.
  # - those that aren't disabled.
  my $domain = $info->{domain};
  my $dbt = dbdef->table($domain);
  my $hashref = {};
  if ( $param->{'agentnum'} and $dbt->column('agentnum') ) {
    $hashref->{'agentnum'} = $param->{'agentnum'};
  }
  if ( $dbt->column('disabled') ) {
    $hashref->{'disabled'} = '';
  }
  my @records = qsearch($domain, $hashref);
  my $num_targets = scalar(@records);
  return if $num_targets == 0;
  my $sent = 0;

  my $outbuf;
  my ($fs_interp) = mason_interps('standalone', 'outbuf' => \$outbuf);
  # if generating the report fails, we want to capture the error and exit,
  # not send it.
  $fs_interp->error_mode('fatal');
  $fs_interp->error_format('brief');

  # we have to at least have an RT::Handle
  require RT;
  RT::LoadConfig();
  RT::Init();

  # hold onto all the reports until we're sure they generated correctly.
  my %cust_main;
  my %report_content;

  # grab the stylesheet
  ### note: if we need the ability to support different stylesheets, this
  ### is the place to put it in
  eval { $fs_interp->exec('/elements/freeside.css') };
  die "couldn't load stylesheet via Mason: $@\n" if $@;
  my $stylesheet = $outbuf;

  my $pkey = $dbt->primary_key;
  foreach my $rec (@records) {

    $job->update_statustext(int( 100 * $sent / $num_targets ));
    my $pkey_val = $rec->get($pkey); # e.g. sales.salesnum

    # find the customer we're sending to, and their email
    my $cust_main;
    if ( $info->{'cust_main'} ) {
      my $cust_method = $info->{'cust_main'};
      $cust_main = $rec->$cust_method;
    } elsif ( $rec->custnum ) {
      $cust_main = FS::cust_main->by_key($rec->custnum);
    } else {
      warn "$pkey = $pkey_val has no custnum; not sending report\n";
      next;
    }
    my @email = $cust_main->invoicing_list_emailonly;
    if (!@email) {
      warn "$pkey = $pkey_val has no email destinations\n" if $DEBUG;
      next;
    }

    # params to send to the report (as if from the user's browser)
    my @report_param = ( # maybe list these in $info
      agentnum  => $param->{'agentnum'},
      beginning => $param->{'beginning'},
      ending    => $param->{'ending'},
      $pkey     => $pkey_val,
      _type     => 'html-print',
    );

    # build a query string
    my $query_string = '';
    while (@report_param) {
      $query_string .= uri_escape(shift @report_param)
                    .  '='
                    .  uri_escape(shift @report_param);
      $query_string .= ';' if @report_param;
    }
    warn "$path?$query_string\n\n" if $DEBUG;

    # run the report!
    $FS::Mason::Request::QUERY_STRING = $query_string;
    $FS::Mason::Request::FSURL = '';
    $outbuf = '';
    eval { $fs_interp->exec($path) };
    die "creating report for $pkey = $pkey_val: $@" if $@;

    # make some adjustments to the report
    my $html_defang;
    $html_defang = HTML::Defang->new(
      url_callback      => sub { 1 }, # strip all URLs (they're not accessible)
      tags_to_callback  => [ 'body' ], # and after the BODY tag...
      tags_callback     => sub {
        my $isEndTag = $_[4];
        $html_defang->add_to_output("\n<style>\n$stylesheet\n</style>\n")
          unless $isEndTag;
      },
    );
    $outbuf = $html_defang->defang($outbuf);

    $cust_main{ $cust_main->custnum } = $cust_main;
    $report_content{ $cust_main->custnum } = $outbuf;
  } # foreach $rec

  $job->update_statustext('Sending reports...');
  foreach my $custnum (keys %cust_main) {
    # create an email message with the report as body
    # change this when backporting to 3.x
    $template->send(
      cust_main         => $cust_main{$custnum},
      object            => $cust_main{$custnum},
      msgtype           => 'report',
      override_content  => $report_content{$custnum},
    );
  }

  my $self = FS::report_batch->new({
    reportname  => $param->{'reportname'},
    agentnum    => $param->{'agentnum'},
    sdate       => parse_datetime($param->{'beginning'}),
    edate       => parse_datetime($param->{'ending'}),
    usernum     => $job->usernum,
    msgnum      => $param->{'msgnum'},
  });
  my $error = $self->insert;
  warn "error recording completion of report: $error\n" if $error;

}

=head1 SEE ALSO

L<FS::Record>

=cut

1;

