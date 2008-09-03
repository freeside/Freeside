package FS::cust_pkg_reason;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_pkg_reason - Object methods for cust_pkg_reason records

=head1 SYNOPSIS

  use FS::cust_pkg_reason;

  $record = new FS::cust_pkg_reason \%hash;
  $record = new FS::cust_pkg_reason { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_reason object represents a relationship between a cust_pkg
and a reason, for example cancellation or suspension reasons. 
FS::cust_pkg_reason inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item num - primary key

=item pkgnum - 

=item reasonnum - 

=item otaker - 

=item date - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cust_pkg_reason.  To add the example to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pkg_reason'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid cust_pkg_reason.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_number('pkgnum')
    || $self->ut_number('reasonnum')
    || $self->ut_enum('action', [ 'A', 'C', 'E', 'S' ])
    || $self->ut_text('otaker')
    || $self->ut_numbern('date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item reason

Returns the reason (see L<FS::reason>) associated with this cust_pkg_reason.

=cut

sub reason {
  my $self = shift;
  qsearchs( 'reason', { 'reasonnum' => $self->reasonnum } );
}

=item reasontext

Returns the text of the reason (see L<FS::reason>) associated with this
cust_pkg_reason.

=cut

sub reasontext {
  my $reason = shift->reason;
  $reason ? $reason->reason : '';
}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data { # class method
  my ($class, %opts) = @_;

  my $test_cust_pkg_reason = new FS::cust_pkg_reason;
  return '' unless $test_cust_pkg_reason->dbdef_table->column('action');

  my $count = 0;
  my @unmigrated = qsearch('cust_pkg_reason', { 'action' => '' } ); 
  foreach ( @unmigrated ) {
    # we could create h_cust_pkg_reason and h_cust_pkg_reason packages
    @FS::h_cust_pkg::ISA = qw( FS::h_Common FS::cust_pkg );
    sub FS::h_cust_pkg::table { 'h_cust_pkg' };
    @FS::h_cust_pkg_reason::ISA = qw( FS::h_Common FS::cust_pkg_reason );
    sub FS::h_cust_pkg_reason::table { 'h_cust_pkg_reason' };

    my @history_cust_pkg_reason = qsearch( 'h_cust_pkg_reason', { $_->hash } );
    
    next unless scalar(@history_cust_pkg_reason) == 1;

    my %action_value = ( op    => 'LIKE',
                         value => 'replace_%',
                       );
    my $hashref = { pkgnum => $_->pkgnum,
                    history_date   => $history_cust_pkg_reason[0]->history_date,
                    history_action => { %action_value },
                  };

    my @history = qsearch({ table    => 'h_cust_pkg',
                            hashref  => $hashref,
                            order_by => 'ORDER BY history_action',
                         });

    if (@history < 2) {
      $hashref->{history_date}++;  # more fuzz?
      $hashref->{history_action} = { %action_value }; # qsearch distorts this!
      push @history, qsearch({ table    => 'h_cust_pkg',
                               hashref  => $hashref,
                               order_by => 'ORDER BY history_action',
                            });
    }

    next unless scalar(@history) == 2;

    my @new = grep { $_->history_action eq 'replace_new' } @history;
    my @old = grep { $_->history_action eq 'replace_old' } @history;
    
    next if (scalar(@new) == 2 || scalar(@old) == 2);

    if ( !$old[0]->get('cancel') && $new[0]->get('cancel') ) {
      $_->action('C');
    }elsif( !$old[0]->susp && $new[0]->susp ){
      $_->action('S');
    }elsif( $new[0]->expire &&
            (!$old[0]->expire || !$old[0]->expire != $new[0]->expire )
          ){
      $_->action('E');
    }elsif( $new[0]->adjourn &&
            (!$old[0]->adjourn || $old[0]->adjourn != $new[0]->adjourn )
          ){
      $_->action('A');
    }

    my $error = $_->replace
      if $_->modified;

    die $error if $error;

    $count++;
  }

  #remove nullability if scalar(@migrated) - $count == 0 && ->column('action');
  
  '';

}

=back

=head1 BUGS

Here be termites.  Don't use on wooden computers.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

