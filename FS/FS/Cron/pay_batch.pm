package FS::Cron::pay_batch;

use strict;
use vars qw( @ISA @EXPORT_OK $me $DEBUG );
use Exporter;
use Date::Format;
use FS::UID qw(dbh);
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::queue;
use FS::agent;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( pay_batch_submit pay_batch_receive );
$DEBUG = 0;
$me = '[FS::Cron::pay_batch]';

#freeside-daily %opt:
#  -v: enable debugging
#  -l: debugging level
#  -m: Experimental multi-process mode uses the job queue for multi-process and/or multi-machine billing.
#  -r: Multi-process mode dry run option
#  -a: Only process customers with the specified agentnum

sub batch_gateways {
  my $conf = FS::Conf->new;
  # returns a list of arrayrefs: [ gateway, payby, agentnum ]
  my %opt = @_;
  my @agentnums;
  if ( $conf->exists('batch-spoolagent') ) {
    if ( $opt{a} ) {
      @agentnums = split(',', $opt{a});
    } else {
      @agentnums = map { $_->agentnum } qsearch('agent');
    }
  } else {
    @agentnums = ('');
    if ( $opt{a} ) {
      warn "Payment batch processing skipped in per-agent mode.\n" if $DEBUG;
      return;
    }
  }
  my @return;
  foreach my $agentnum (@agentnums) {
    my %gateways;
    foreach my $payby ('CARD', 'CHEK') {
      my $gatewaynum = $conf->config("batch-gateway-$payby", $agentnum);
      next if !$gatewaynum;
      my $gateway = FS::payment_gateway->by_key($gatewaynum)
        or die "payment_gateway '$gatewaynum' not found\n";
      push @return, [ $gateway, $payby, $agentnum ];
    }
  }
  @return;
}

sub pay_batch_submit {
  my %opt = @_;
  local $DEBUG = ($opt{l} || 1) if $opt{v};
  # if anything goes wrong, don't try to roll back previously submitted batches
  local $FS::UID::AutoCommit = 1;
  
  my $dbh = dbh;

  warn "$me batch_submit\n" if $DEBUG;
  foreach my $config (batch_gateways(%opt)) {
    my ($gateway, $payby, $agentnum) = @$config;
    if ( $gateway->batch_processor->can('default_transport') ) {

      my $search = { status => 'O', payby => $payby };
      $search->{agentnum} = $agentnum if $agentnum;

      foreach my $pay_batch ( qsearch('pay_batch', $search) ) {

        warn "Exporting batch ".$pay_batch->batchnum."\n" if $DEBUG;
        eval { $pay_batch->export_to_gateway( $gateway, debug => $DEBUG ); };

        if ( $@ ) {
          # warn the error and continue. rolling back the transaction once 
          # we've started sending batches is bad.
          warn "error submitting batch ".$pay_batch->batchnum." to gateway '".
          $gateway->label."\n$@\n";
        }
      }

    } else { #can't(default_transport)
      warn "Payment gateway '".$gateway->label.
      "' doesn't support automatic transport; skipped.\n";
    }
  } #$payby

  1;
}

sub pay_batch_receive {
  my %opt = @_;
  local $DEBUG = ($opt{l} || 1) if $opt{v};
  local $FS::UID::AutoCommit = 0;

  my $dbh = dbh;
  my $error;

  warn "$me batch_receive\n" if $DEBUG;

  my %gateway_done;
    # If a gateway is selected for more than one payby+agentnum, still
    # only import from it once; we expect it will send back multiple
    # result batches.
  foreach my $config (batch_gateways(%opt)) {
    my ($gateway, $payby, $agentnum) = @$config;
    next if $gateway_done{$gateway->gatewaynum};
    next unless $gateway->batch_processor->can('default_transport');
    # already warned about this above
    warn "Importing results from '".$gateway->label."'\n" if $DEBUG;
    # Note that import_from_gateway is not agent-limited; if a gateway
    # returns results for batches not associated with this agent, we will
    # still accept them. Well-behaved gateways will not do that.
    $error = eval { 
      FS::pay_batch->import_from_gateway( gateway =>$gateway, debug => $DEBUG ) 
    } || $@;
    if ( $error ) {
      # this we can roll back
      $dbh->rollback;
      die "error receiving from gateway '".$gateway->label."':\n$error\n";
    }
  } #$gateway

  # resolve batches if we can
  foreach my $pay_batch (qsearch('pay_batch', { status => 'I' })) {
    warn "Trying to resolve batch ".$pay_batch->batchnum."\n" if $DEBUG;
    $error = $pay_batch->try_to_resolve;
    if ( $error ) {
      $dbh->rollback;
      die "unable to resolve batch ".$pay_batch->batchnum.":\n$error\n";
    }
  }

  $dbh->commit;
}
1;
