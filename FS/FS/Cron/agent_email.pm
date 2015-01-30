package FS::Cron::agent_email;
use base qw( Exporter );

use strict;
use vars qw( @EXPORT_OK $DEBUG );
use Date::Simple qw(today);
use URI::Escape;
use FS::Mason qw( mason_interps );
use FS::Conf;
use FS::Misc qw(send_email);
use FS::Record qw(qsearch);# qsearchs);
use FS::agent;

@EXPORT_OK = qw ( agent_email );
$DEBUG = 0;

sub agent_email {
  my %opt = @_;

  my $conf = new FS::Conf;

  my $day = $conf->config('agent-email_day') or return;
  return unless $day == today->day;

  if ( 1 ) { #XXX if ( %%%RT_ENABLED%%% ) {
    require RT;
    RT::LoadConfig();
    RT::Init();
    RT::ConnectToDatabase();
  }

  my $from = $conf->invoice_from_full();

  my $outbuf = '';;
  my( $fs_interp, $rt_interp ) = mason_interps('standalone', 'outbuf'=>\$outbuf);

  my $comp = '/search/cust_main.html';
  my %args = (
    'cust_fields' => 'Cust# | Cust. Status | Customer | Current Balance',
    '_type'       => 'html-print',
  );
  my $query = join('&', map "$_=".uri_escape($args{$_}), keys %args );

  my $extra_sql = $opt{a} ? " AND agentnum IN ( $opt{a} ) " : '';

  foreach my $agent ( qsearch({
                        'table'     => 'agent',
                        'hashref'   => {
                          'disabled'      => '',
                          'agent_custnum' => { op=>'!=', value=>'' },
                        },
                        'extra_sql' => $extra_sql,
                      })
                    )
  {

    $FS::Mason::Request::QUERY_STRING = $query. '&agentnum='. $agent->agentnum;
    $fs_interp->exec($comp);

    my @email = $agent->agent_cust_main->invoicing_list or next;

    warn "emailing ". join(',',@email). " for agent ". $agent->agent. "\n"
      if $DEBUG;
    send_email(
      'from'         => $from,
      'to'           => \@email,
      'subject'      => 'Customer report',
      'body'         => $outbuf,
      'content-type' => 'text/html',
      #'content-encoding'
    ); 

    $outbuf = '';

  }

}

1;
