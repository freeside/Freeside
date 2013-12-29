package FS::export_svc;
use base qw(FS::Record);

use strict;
use FS::Record qw( dbh qsearch ); #qsearchs );
use FS::svc_export_machine;

=head1 NAME

FS::export_svc - Object methods for export_svc records

=head1 SYNOPSIS

  use FS::export_svc;

  $record = new FS::export_svc \%hash;
  $record = new FS::export_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_svc object links a service definition (see L<FS::part_svc>) to
an export (see L<FS::part_export>).  FS::export_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item exportsvcnum - primary key

=item exportnum - export (see L<FS::part_export>)

=item svcpart - service definition (see L<FS::part_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'export_svc'; }

=item insert [ JOB, OFFSET, MULTIPLIER ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

TODOC: JOB, OFFSET, MULTIPLIER

=cut

sub insert {
  my $self = shift;
  my( $job, $offset, $mult ) = ( '', 0, 100);
  $job = shift if @_;
  $offset = shift if @_;
  $mult = shift if @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->check;
  return $error if $error;

  #check for duplicates!
  my @checks = ();
  my $svcdb = $self->part_svc->svcdb;
  if ( $svcdb eq 'svc_acct' ) {

    if ( $self->part_export->nodomain =~ /^Y/i ) {
      push @checks, {
        label  => 'usernames',
        method => 'username',
        sortby => sub { $a cmp $b },
      };
    } else {
      push @checks, {
        label  => 'username@domain',
        method => 'email',
        sortby => sub {
                        my($auser, $adomain) = split('@', $a);
                        my($buser, $bdomain) = split('@', $b);
                        $adomain cmp $bdomain || $auser cmp $buser;
                      },
      };
    }

    unless ( $self->part_svc->part_svc_column('uid')->columnflag eq 'F' ) {
      push @checks, {
        label  => 'uids',
        method => 'uid',
        sortby => sub { $a <=> $b },
      };
    }

  } elsif ( $svcdb eq 'svc_domain' ) {
    push @checks, {
      label  => 'domains',
      method => 'domain',
      sortby => sub { $a cmp $b },
    };
  } else {
    warn "WARNING: No duplicate checking done on merge of $svcdb exports";
  }

  if ( @checks ) {
  
    my $done = 0;
    my $percheck = $mult / scalar(@checks);

    foreach my $check ( @checks ) {
  
      if ( $job ) {
        $error = $job->update_statustext(int( $offset + ($done+.33) *$percheck ));
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
  
      my @current_svc = $self->part_export->svc_x;
      #warn "current: ". scalar(@current_svc). " $current_svc[0]\n";
  
      if ( $job ) {
        $error = $job->update_statustext(int( $offset + ($done+.67) *$percheck ));
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
  
      my @new_svc = $self->part_svc->svc_x;
      #warn "new: ". scalar(@new_svc). " $new_svc[0]\n";
  
      if ( $job ) {
        $error = $job->update_statustext(int( $offset + ($done+1) *$percheck ));
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
  
      my $method = $check->{'method'};
      my %cur_svc = map { $_->$method() => $_ } @current_svc;
      my @dup_svc = grep { $cur_svc{$_->$method()} } @new_svc;
      #my @diff_customer = grep { 
      #                           $_->cust_pkg->custnum != $cur_svc{$_->$method()}->cust_pkg->custnum
      #                         } @dup_svc;
  
  
  
      if ( @dup_svc ) { #aye, that's the rub
        #error out for now, eventually accept different options of adjustments
        # to make to allow us to continue forward
        $dbh->rollback if $oldAutoCommit;
  
        my @diff_customer_svc = grep {
          my $cust_pkg = $_->cust_svc->cust_pkg;
          my $custnum = $cust_pkg ? $cust_pkg->custnum : 0;
          my $other_cust_pkg = $cur_svc{$_->$method()}->cust_svc->cust_pkg;
          my $other_custnum = $other_cust_pkg ? $other_cust_pkg->custnum : 0;
          $custnum != $other_custnum;
        } @dup_svc;
  
        my $label = $check->{'label'};
        my $sortby = $check->{'sortby'};
        return "Can't export ".
               $self->part_svc->svcpart.':'.$self->part_svc->svc. " service to ".
               $self->part_export->exportnum.':'.$self->part_export->exporttype.
                 ' on '. $self->part_export->machine.
               ' : '. scalar(@dup_svc). " duplicate $label".
               ' ('. scalar(@diff_customer_svc). " from different customers)".
               ": ". join(', ', sort $sortby map { $_->$method() } @dup_svc )
               #": ". join(', ', sort $sortby map { $_->$method() } @diff_customer_svc )
               ;
      }
  
      $done++;
    }

  } #end of duplicate check, whew

  $error = $self->SUPER::insert;

  my $part_export = $self->part_export;
  if ( !$error and $part_export->default_machine ) {
    foreach my $cust_svc ( $self->part_svc->cust_svc ) {
      my $svc_export_machine = FS::svc_export_machine->new({
          'exportnum'   => $self->exportnum,
          'svcnum'      => $cust_svc->svcnum,
          'machinenum'  => $part_export->default_machine,
      });
      $error ||= $svc_export_machine->insert;
    }
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

#  if ( $self->part_svc->svcdb eq 'svc_acct' ) {
#
#    if ( $self->part_export->nodomain =~ /^Y/i ) {
#
#      select username from svc_acct where svcpart = $svcpart
#        group by username having count(*) > 1;
#
#    } else {
#
#      select username, domain
#        from   svc_acct
#          join svc_domain on ( svc_acct.domsvc = svc_domain.svcnum )
#        group by username, domain having count(*) > 1;
#
#    }
#
#  } elsif ( $self->part_svc->svcdb eq 'svc_domain' ) {
#
#    #similar but easier domain checking one
#
#  } #etc.?
#
#  my @services =
#    map  { $_->part_svc }
#    grep { $_->svcpart != $self->svcpart }
#         $self->part_export->export_svc;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error = $self->SUPER::delete;
  foreach ($self->svc_export_machine) {
    $error ||= $_->delete;
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('exportsvcnum')
    || $self->ut_number('exportnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_number('svcpart')
    || $self->ut_foreign_key('svcpart', 'part_svc', 'svcpart')
    || $self->SUPER::check
  ;
}

=item part_export

Returns the FS::part_export object (see L<FS::part_export>).

=item part_svc

Returns the FS::part_svc object (see L<FS::part_svc>).

=item svc_export_machine

Returns all export hostname records (L<FS::svc_export_machine>) for this
combination of svcpart and exportnum.

=cut

sub svc_export_machine {
  my $self = shift;
  qsearch({
    'table'     => 'svc_export_machine',
    'select'    => 'svc_export_machine.*',
    'addl_from' => 'JOIN cust_svc USING (svcnum)',
    'hashref'   => { 'exportnum' => $self->exportnum },
    'extra_sql' => ' AND cust_svc.svcpart = '.$self->svcpart,
  });
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::part_svc>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

