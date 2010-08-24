package FS::pay_batch;

use strict;
use vars qw( @ISA $DEBUG %import_info %export_info $conf );
use Time::Local;
use Text::CSV_XS;
use FS::Record qw( dbh qsearch qsearchs );
use FS::cust_pay;
use FS::Conf;

@ISA = qw(FS::Record);

=head1 NAME

FS::pay_batch - Object methods for pay_batch records

=head1 SYNOPSIS

  use FS::pay_batch;

  $record = new FS::pay_batch \%hash;
  $record = new FS::pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pay_batch object represents an payment batch.  FS::pay_batch inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item batchnum - primary key

=item payby - CARD or CHEK

=item status - O (Open), I (In-transit), or R (Resolved)

=item download - 

=item upload - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new batch.  To add the batch to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'pay_batch'; }

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

Checks all fields to make sure this is a valid batch.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('batchnum')
    || $self->ut_enum('payby', [ 'CARD', 'CHEK' ])
    || $self->ut_enum('status', [ 'O', 'I', 'R' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rebalance

=cut

sub rebalance {
  my $self = shift;
}

=item set_status 

=cut

sub set_status {
  my $self = shift;
  $self->status(shift);
  $self->download(time)
    if $self->status eq 'I' && ! $self->download;
  $self->upload(time)
    if $self->status eq 'R' && ! $self->upload;
  $self->replace();
}

# further false laziness

%import_info = %export_info = ();
foreach my $INC (@INC) {
  warn "globbing $INC/FS/pay_batch/*.pm\n" if $DEBUG;
  foreach my $file ( glob("$INC/FS/pay_batch/*.pm")) {
    warn "attempting to load batch format from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/;
    next if !$1;
    my $mod = $1;
    my ($import, $export, $name) = 
      eval "use FS::pay_batch::$mod; 
           ( \\%FS::pay_batch::$mod\::import_info,
             \\%FS::pay_batch::$mod\::export_info,
             \$FS::pay_batch::$mod\::name)";
    $name ||= $mod; # in case it's not defined
    if( $@) {
      # in FS::cdr this is a die, not a warn.  That's probably a bug.
      warn "error using FS::pay_batch::$mod (skipping): $@\n";
      next;
    }
    if(!keys(%$import)) {
      warn "no \%import_info found in FS::pay_batch::$mod (skipping)\n";
    }
    else {
      $import_info{$name} = $import;
    }
    if(!keys(%$export)) {
      warn "no \%export_info found in FS::pay_batch::$mod (skipping)\n";
    }
    else {
      $export_info{$name} = $export;
    }
  }
}

=item import_results OPTION => VALUE, ...

Import batch results.

Options are:

I<filehandle> - open filehandle of results file.

I<format> - "csv-td_canada_trust-merchant_pc_batch", "csv-chase_canada-E-xactBatch", "ach-spiritone", or "PAP"

=cut

sub import_results {
  my $self = shift;

  my $param = ref($_[0]) ? shift : { @_ };
  my $fh = $param->{'filehandle'};
  my $format = $param->{'format'};
  my $info = $import_info{$format}
    or die "unknown format $format";

  my $job = $param->{'job'};
  $job->update_statustext(0) if $job;

  my $filetype            = $info->{'filetype'};      # CSV or fixed
  my @fields              = @{ $info->{'fields'}};
  my $formatre            = $info->{'formatre'};      # for fixed
  my @all_values;
  my $begin_condition     = $info->{'begin_condition'};
  my $end_condition       = $info->{'end_condition'};
  my $end_hook            = $info->{'end_hook'};
  my $skip_condition      = $info->{'skip_condition'};
  my $hook                = $info->{'hook'};
  my $approved_condition  = $info->{'approved'};
  my $declined_condition  = $info->{'declined'};

  my $csv = new Text::CSV_XS;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $reself = $self->select_for_update;

  unless ( $reself->status eq 'I' ) {
    $dbh->rollback if $oldAutoCommit;
    return "batchnum ". $self->batchnum. "no longer in transit";
  }

  my $error = $self->set_status('R');
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $total = 0;
  my $line;

  # Order of operations has been changed here.
  # We now slurp everything into @all_values, then 
  # process one line at a time.

  if ($filetype eq 'XML') {
    eval "use XML::Simple";
    die $@ if $@;
    my @xmlkeys = @{ $info->{'xmlkeys'} };  # for XML
    my $xmlrow  = $info->{'xmlrow'};        # also for XML

    # Do everything differently.
    my $data = XML::Simple::XMLin($fh, KeepRoot => 1);
    my $rows = $data;
    # $xmlrow = [ RootKey, FirstLevelKey, SecondLevelKey... ]
    $rows = $rows->{$_} foreach( @$xmlrow );
    if(!defined($rows)) {
      $dbh->rollback if $oldAutoCommit;
      return "can't find rows in XML file";
    }
    $rows = [ $rows ] if ref($rows) ne 'ARRAY';
    foreach my $row (@$rows) {
      push @all_values, [ @{$row}{@xmlkeys}, $row ];
    }
  }
  else {
    while ( defined($line=<$fh>) ) {

      next if $line =~ /^\s*$/; #skip blank lines

      if ($filetype eq "CSV") {
        $csv->parse($line) or do {
          $dbh->rollback if $oldAutoCommit;
          return "can't parse: ". $csv->error_input();
        };
        push @all_values, [ $csv->fields(), $line ];
      }elsif ($filetype eq 'fixed'){
        my @values = ( $line =~ /$formatre/ );
        unless (@values) {
          $dbh->rollback if $oldAutoCommit;
          return "can't parse: ". $line;
        };
        push @values, $line;
        push @all_values, \@values;
      }else{
        $dbh->rollback if $oldAutoCommit;
        return "Unknown file type $filetype";
      }
    }
  }

  my $num = 0;
  foreach (@all_values) {
    if($job) {
      $num++;
      $job->update_statustext(int(100 * $num/scalar(@all_values)));
    }
    my @values = @$_;

    my %hash;
    my $line = pop @values;
    foreach my $field ( @fields ) {
      my $value = shift @values;
      next unless $field;
      $hash{$field} = $value;
    }

    if ( defined($begin_condition) ) {
      if ( &{$begin_condition}(\%hash, $line) ) {
        undef $begin_condition;
      }
      else {
        next;
      }
    }

    if ( defined($end_condition) and &{$end_condition}(\%hash, $line) ) {
      my $error;
      $error = &{$end_hook}(\%hash, $total, $line) if defined($end_hook);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      last;
    }

    if ( defined($skip_condition) and &{$skip_condition}(\%hash, $line) ) {
      next;
    }

    my $cust_pay_batch =
      qsearchs('cust_pay_batch', { 'paybatchnum' => $hash{'paybatchnum'}+0 } );
    unless ( $cust_pay_batch ) {
      return "unknown paybatchnum $hash{'paybatchnum'}\n";
    }
    my $custnum = $cust_pay_batch->custnum,
    my $payby = $cust_pay_batch->payby,

    my $new_cust_pay_batch = new FS::cust_pay_batch { $cust_pay_batch->hash };

    &{$hook}(\%hash, $cust_pay_batch->hashref);

    if ( &{$approved_condition}(\%hash) ) {

      $new_cust_pay_batch->status('Approved');

    } elsif ( &{$declined_condition}(\%hash) ) {

      $new_cust_pay_batch->status('Declined');

    }

    my $error = $new_cust_pay_batch->replace($cust_pay_batch);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error updating status of paybatchnum $hash{'paybatchnum'}: $error\n";
    }

    # purge CVV when the batch is processed
    $new_cust_pay_batch->cust_main->remove_cvv
      if ( $payby eq 'CARD' or $payby eq 'DCRD' );

    if ( $new_cust_pay_batch->status =~ /Approved/i ) {

      my $cust_pay = new FS::cust_pay ( {
        'custnum'  => $custnum,
	'payby'    => $payby,
        'paybatch' => $self->batchnum,
        'payinfo'  => ( $hash{'payinfo'} || $cust_pay_batch->payinfo ),
        map { $_ => $hash{$_} } (qw( paid _date )),
      } );
      $error = $cust_pay->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error adding payment paybatchnum $hash{'paybatchnum'}: $error\n";
      }
      $total += $hash{'paid'};
  
      $cust_pay->cust_main->apply_payments;

    } elsif ( $new_cust_pay_batch->status =~ /Declined/i ) {

      #false laziness w/cust_main::collect

      my $due_cust_event = $new_cust_pay_batch->cust_main->due_cust_event(
        #'check_freq' => '1d', #?
        'eventtable' => 'cust_pay_batch',
        'objects'    => [ $new_cust_pay_batch ],
      );
      unless( ref($due_cust_event) ) {
        $dbh->rollback if $oldAutoCommit;
        return $due_cust_event;
      }

      foreach my $cust_event ( @$due_cust_event ) {
        
        #XXX lock event
    
        #re-eval event conditions (a previous event could have changed things)
        next unless $cust_event->test_conditions;

	if ( my $error = $cust_event->do_event() ) {
	  # gah, even with transactions.
	  #$dbh->commit if $oldAutoCommit; #well.
	  $dbh->rollback if $oldAutoCommit;
          return $error;
	}

      } # foreach $cust_event

    } # if(status eq 'Approved')

  } # foreach(@all_values)
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

use MIME::Base64;
use Storable 'thaw';
use Data::Dumper;
sub process_import_results {
  my $job = shift;
  my $param = thaw(decode_base64(shift));
  $param->{'job'} = $job;
  warn Dumper($param) if $DEBUG;
  my $batchnum = delete $param->{'batchnum'} or die "no batchnum specified\n";
  my $batch = FS::pay_batch->by_key($batchnum) or die "batchnum '$batchnum' not found\n";

  my $file = $param->{'uploaded_files'} or die "no files provided\n";
  $file =~ s/^(\w+):([\.\w]+)$/$2/;
  my $dir = '%%%FREESIDE_CACHE%%%/cache.' . $FS::UID::datasrc;
  open( $param->{'filehandle'}, 
        '<',
        "$dir/$file" )
      or die "unable to open '$file'.\n";
  my $error = $batch->import_results($param);
  unlink $file;
  die $error if $error;
}

# Formerly httemplate/misc/download-batch.cgi
sub export_batch {
  my $self = shift;
  my $conf = new FS::Conf;
  my $format = shift || $conf->config('batch-default_format')
               or die "No batch format configured\n";
  my $info = $export_info{$format} or die "Format not found: '$format'\n";
  &{$info->{'init'}}($conf) if exists($info->{'init'});

  my $curuser = $FS::CurrentUser::CurrentUser;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;  

  my $first_download;
  my $status = $self->status;
  if ($status eq 'O') {
    $first_download = 1;
    my $error = $self->set_status('I');
    die "error updating pay_batch status: $error\n" if $error;
  } elsif ($status eq 'I' && $curuser->access_right('Reprocess batches')) {
    $first_download = 0;
  } else {
    die "No pending batch.\n";
  }

  my $batch = '';
  my $batchtotal = 0;
  my $batchcount = 0;

  my @cust_pay_batch = sort { $a->paybatchnum <=> $b->paybatchnum }
                      qsearch('cust_pay_batch', { batchnum => $self->batchnum } );

  my $h = $info->{'header'};
  if(ref($h) eq 'CODE') {
    $batch .= &$h($self, \@cust_pay_batch) . "\n";
  }
  else {
    $batch .= $h . "\n";
  }
  foreach my $cust_pay_batch (@cust_pay_batch) {

    if ($first_download) {
      my $balance = $cust_pay_batch->cust_main->balance;
      if ($balance <= 0) { # then don't charge this customer
        my $error = $cust_pay_batch->delete;
        if ( $error ) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
        next;
      } elsif ($balance < $cust_pay_batch->amount) {
        # reduce the charge to the remaining balance
        $cust_pay_batch->amount($balance);
        my $error = $cust_pay_batch->replace;
        if ( $error ) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
      }
      # else $balance >= $cust_pay_batch->amount
    }

    $batchcount++;
    $batchtotal += $cust_pay_batch->amount;
    $batch .= &{$info->{'row'}}($cust_pay_batch, $self, $batchcount, $batchtotal) . "\n";

  }

  my $f = $info->{'footer'};
  if(ref($f) eq 'CODE') {
    $batch .= &$f($self, $batchcount, $batchtotal) . "\n";
  }
  else {
    $batch .= $f . "\n";
  }

  if ($info->{'autopost'}) {
    my $error = &{$info->{'autopost'}}($self, $batch);
    if($error) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return $batch;
}

=back

=head1 BUGS

status is somewhat redundant now that download and upload exist

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

