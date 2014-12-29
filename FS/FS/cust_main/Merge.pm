package FS::cust_main::Merge;

use strict;
use vars qw( $conf );
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::agent;
use FS::access_user;
use FS::cust_pay_pending;
use FS::cust_tag;
use FS::cust_location;
use FS::contact;
use FS::cust_attachment;
use FS::cust_main_note;
use FS::cust_tax_adjustment;
use FS::cust_pay_batch;
use FS::queue;
use FS::cust_main_exemption;
use FS::cust_main_invoice;

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
};

#old-style merge, new style is with ->attach_pkgs

=item merge NEW_CUSTNUM [ , OPTION => VALUE ... ]

This merges this customer into the provided new custnum, and then deletes the
customer.  If there is an error, returns the error, otherwise returns false.

The source customer's name, company name, phone numbers, agent,
referring customer, customer class, advertising source, order taker, and
billing information (except balance) are discarded.

All packages are moved to the target customer.  Packages with package locations
are preserved.  Packages without package locations are moved to a new package
location with the source customer's service/shipping address.

All invoices, statements, payments, credits and refunds are moved to the target
customer.  The source customer's balance is added to the target customer.

All notes, attachments, tickets and customer tags are moved to the target
customer.

Change history is not currently moved.

=cut

sub merge {
  my( $self, $new_custnum, %opt ) = @_;

  return "Can't merge a customer into self" if $self->custnum == $new_custnum;

  my $new_cust_main = qsearchs( 'cust_main', { 'custnum' => $new_custnum } )
    or return "Invalid new customer number: $new_custnum";

  return 'Access denied: "Merge customer across agents" access right required to merge into a customer of a different agent'
    if $self->agentnum != $new_cust_main->agentnum 
    && ! $FS::CurrentUser::CurrentUser->access_right('Merge customer across agents');

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( qsearch('agent', { 'agent_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a master agent customer";
  }

  #use FS::access_user
  if ( qsearch('access_user', { 'user_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a master employee customer";
  }

  if ( qsearch('cust_pay_pending', { 'custnum' => $self->custnum,
                                     'status'  => { op=>'!=', value=>'done' },
                                   }
              )
  ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a customer with pending payments";
  }

  tie my %financial_tables, 'Tie::IxHash',
    'cust_bill'         => 'invoices',
    'cust_bill_void'    => 'voided invoices',
    'cust_statement'    => 'statements',
    'cust_credit'       => 'credits',
    'cust_credit_void'  => 'voided credits',
    'cust_pay'          => 'payments',
    'cust_pay_void'     => 'voided payments',
    'cust_refund'       => 'refunds',
  ;
   
  foreach my $table ( keys %financial_tables ) {

    my @records = $self->$table();

    foreach my $record ( @records ) {
      $record->custnum($new_custnum);
      my $error = $record->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "Error merging ". $financial_tables{$table}. ": $error\n";
      }
    }

  }

  my $name = $self->ship_name; #?

  my $locationnum = '';
  foreach my $cust_pkg ( $self->all_pkgs ) {
    $cust_pkg->custnum($new_custnum);

    unless ( $cust_pkg->locationnum ) {
      unless ( $locationnum ) {
        my $cust_location = new FS::cust_location {
          $self->location_hash,
          'custnum' => $new_custnum,
        };
        my $error = $cust_location->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
        $locationnum = $cust_location->locationnum;
      }
      $cust_pkg->locationnum($locationnum);
    }

    my $error = $cust_pkg->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    # add customer (ship) name to svc_phone.phone_name if blank
    my @cust_svc = $cust_pkg->cust_svc;
    foreach my $cust_svc (@cust_svc) {
      my($label, $value, $svcdb) = $cust_svc->label;
      next unless $svcdb eq 'svc_phone';
      my $svc_phone = $cust_svc->svc_x;
      next if $svc_phone->phone_name;
      $svc_phone->phone_name($name);
      my $error = $svc_phone->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

  }

  #not considered:
  # cust_tax_exempt (texas tax exemptions)
  # cust_recon (some sort of not-well understood thing for OnPac)

  #these are moved over
  foreach my $table (qw(
    cust_tag cust_location contact cust_attachment cust_main_note
    cust_tax_adjustment cust_pay_batch queue
  )) {
    foreach my $record ( qsearch( $table, { 'custnum' => $self->custnum } ) ) {
      $record->custnum($new_custnum);
      my $error = $record->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  #these aren't preserved
  foreach my $table (qw(
    cust_main_exemption cust_main_invoice
  )) {
    foreach my $record ( qsearch( $table, { 'custnum' => $self->custnum } ) ) {
      my $error = $record->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }


  my $sth = $dbh->prepare(
    'UPDATE cust_main SET referral_custnum = ? WHERE referral_custnum = ?'
  ) or do {
    my $errstr = $dbh->errstr;
    $dbh->rollback if $oldAutoCommit;
    return $errstr;
  };
  $sth->execute($new_custnum, $self->custnum) or do {
    my $errstr = $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
    return $errstr;
  };

  #tickets

  my $ticket_dbh = '';
  if ($conf->config('ticket_system') eq 'RT_Internal') {
    $ticket_dbh = $dbh;
  } elsif ($conf->config('ticket_system') eq 'RT_External') {
    my ($datasrc, $user, $pass) = $conf->config('ticket_system-rt_external_datasrc');
    $ticket_dbh = DBI->connect($datasrc, $user, $pass, { 'ChopBlanks' => 1 });
      #or die "RT_External DBI->connect error: $DBI::errstr\n";
  }

  if ( $ticket_dbh ) {

    my $ticket_sth = $ticket_dbh->prepare(
      'UPDATE Links SET Target = ? WHERE Target = ?'
    ) or do {
      my $errstr = $ticket_dbh->errstr;
      $dbh->rollback if $oldAutoCommit;
      return $errstr;
    };
    $ticket_sth->execute('freeside://freeside/cust_main/'.$new_custnum,
                         'freeside://freeside/cust_main/'.$self->custnum)
      or do {
        my $errstr = $ticket_sth->errstr;
        $dbh->rollback if $oldAutoCommit;
        return $errstr;
      };

  }

  #delete the customer record

  my $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

1;

