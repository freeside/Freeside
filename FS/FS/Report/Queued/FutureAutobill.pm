package FS::Report::Queued::FutureAutobill;
use strict;
use warnings;
use vars qw( $job );

use FS::Conf;
use FS::cust_main;
use FS::cust_main::Location;
use FS::cust_payby;
use FS::CurrentUser;
use FS::Log;
use FS::Mason qw(mason_interps);
use FS::Record qw( qsearch );
use FS::UI::Web;
use FS::UID qw( dbh );

use DateTime;
use File::Temp;
use Data::Dumper;
use HTML::Entities qw( encode_entities );

=head1 NAME

FS::Report::Queued::FutureAutobill - Future Auto-Bill Transactions Report

=head1 DESCRIPTION

Future Autobill report generated within the job queue.

Report results are saved to temp storage as a Mason fragment
that is rendered by the queued report viewer.

For every customer with a valid auto-bill payment method,
report runs bill_and_collect() for each day, from today through
the report target date.  After recording the results, all
operations are rolled back.

This report relies on the ability to safely run bill_and_collect(),
with all exports and messaging disabled, and then to roll back the
results.

=head1 PARAMETERS

C<agentnum>, C<target_date>

=cut

sub make_report {
  $job = shift;
  my $param = shift;
  my $outbuf;
  my $DEBUG = 0;

  my $time_begin = time();

  my $report_fh = File::Temp->new(
    TEMPLATE => 'report.future_autobill.XXXXXXXX',
    DIR      => sprintf( '%s/cache.%s', $FS::Conf::base_dir, $FS::UID::datasrc ),
    UNLINK   => 0
  ) or die "Cannot create report file: $!";

  if ( $DEBUG ) {
    warn Dumper( $job );
    warn Dumper( $param );
    warn $report_fh;
    warn $report_fh->filename;
  }

  my $curuser = FS::CurrentUser->load_user( $param->{CurrentUser} )
    or die 'Unable to set report user';

  my ( $fs_interp ) = FS::Mason::mason_interps(
    'standalone',
    outbuf => \$outbuf,
  );
  $fs_interp->error_mode('fatal');
  $fs_interp->error_format('text');

  $FS::Mason::Request::QUERY_STRING = sprintf(
    'target_date=%s&agentnum=%s',
    encode_entities( $param->{target_date} ),
    encode_entities( $param->{agentnum} || '' ),
  );
  $FS::Mason::Request::FSURL = $param->{RootURL};

  my $mason_request = $fs_interp->make_request(
    comp => '/search/future_autobill.html'
  );

  {
    local $@;
    eval{ $mason_request->exec() };
    if ( $@ ) {
      my $error = ref $@ eq 'HTML::Mason::Exception' ? $@->error : $@;

      my $log = FS::Log->new('FS::Report::Queued::FutureAutobill');
      $log->error(
        "Error generating report: $FS::Mason::Request::QUERY_STRING $error"
      );
      die $error;
    }
  }

  my $report_fn;
  if ( $report_fh->filename =~ /report\.(future_autobill.+)$/ ) {
      $report_fn = $1
  } else {
    die 'Error parsing report filename '.$report_fh->filename;
  }

  my $report_title = FS::cust_payby->future_autobill_report_title();
  my $time_rendered = time() - $time_begin;

  if ( $DEBUG ) {
    warn "Generated content:\n";
    warn $outbuf;
    warn $report_fn;
    warn $report_title;
  }

  print $report_fh qq{<% include("/elements/header.html", '$report_title') %>\n};
  print $report_fh $outbuf;
  print $report_fh qq{<!-- Time to render report $time_rendered seconds -->};
  print $report_fh qq{<% include("/elements/footer.html") %>\n};

  die sprintf
    "<a href=%s/misc/queued_report.html?report=%s>view</a>\n",
    $param->{RootURL},
    $report_fn;
}

1;
