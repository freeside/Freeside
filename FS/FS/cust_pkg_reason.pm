package FS::cust_pkg_reason;

use strict;
use vars qw( $ignore_empty_action );
use base qw( FS::otaker_Mixin FS::Record );
use FS::Record qw( qsearch qsearchs );

$ignore_empty_action = 0;

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

=item num

primary key

=item pkgnum

=item reasonnum

=item usernum

=item date

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

  my @actions = ( 'A', 'C', 'E', 'S' );
  push @actions, '' if $ignore_empty_action;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_number('pkgnum')
    || $self->ut_number('reasonnum')
    || $self->ut_enum('action', \@actions)
    || $self->ut_alphan('otaker')
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

use FS::h_cust_pkg;
use FS::h_cust_pkg_reason;

sub _upgrade_data { # class method
  my ($class, %opts) = @_;

  my $action_replace =
    " AND ( history_action = 'replace_old' OR history_action = 'replace_new' )";

  my $count = 0;
  my @unmigrated = qsearch('cust_pkg_reason', { 'action' => '' } ); 
  foreach ( @unmigrated ) {

    my @history_cust_pkg_reason = qsearch( 'h_cust_pkg_reason', { $_->hash } );
    
    next unless scalar(@history_cust_pkg_reason) == 1;

    my $hashref = { pkgnum => $_->pkgnum,
                    history_date   => $history_cust_pkg_reason[0]->history_date,
                  };

    my @history = qsearch({ table     => 'h_cust_pkg',
                            hashref   => $hashref,
                            extra_sql => $action_replace,
                            order_by  => 'ORDER BY history_action',
                         });

    my $fuzz = 0;
    while (scalar(@history) < 2 && $fuzz < 3) {
      $hashref->{history_date}++;
      $fuzz++;
      push @history, qsearch({ table     => 'h_cust_pkg',
                               hashref   => $hashref,
                               extra_sql => $action_replace,
                               order_by  => 'ORDER BY history_action',
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
      $_->date($new[0]->expire);
    }elsif( $new[0]->adjourn &&
            (!$old[0]->adjourn || $old[0]->adjourn != $new[0]->adjourn )
          ){
      $_->action('A');
      $_->date($new[0]->adjourn);
    }

    my $error = $_->replace
      if $_->modified;

    die $error if $error;

    $count++;
  }

  #remove nullability if scalar(@migrated) - $count == 0 && ->column('action');
  
  #seek expirations/adjourns without reason
  foreach my $field qw( expire adjourn cancel susp ) {
    my $addl_from =
      "LEFT JOIN h_cust_pkg ON ".
      "(cust_pkg_reason.pkgnum = h_cust_pkg.pkgnum AND".
      " cust_pkg_reason.date = h_cust_pkg.$field AND".
      " history_action = 'replace_new')";

    my $extra_sql = 'AND h_cust_pkg.pkgnum IS NULL';

    my @unmigrated = qsearch({ table   => 'cust_pkg_reason',
                               hashref => { action => uc(substr($field,0,1)) },
                               addl_from => $addl_from,
                               select    => 'cust_pkg_reason.*',
                               extra_sql => $extra_sql,
                            }); 
    foreach ( @unmigrated ) {

      my $hashref = { pkgnum => $_->pkgnum,
                      history_date   => $_->date,
                    };

      my @history = qsearch({ table     => 'h_cust_pkg',
                              hashref   => $hashref,
                              extra_sql => $action_replace,
                              order_by  => 'ORDER BY history_action',
                           });

      my $fuzz = 0;
      while (scalar(@history) < 2 && $fuzz < 3) {
        $hashref->{history_date}++;
        $fuzz++;
        push @history, qsearch({ table    => 'h_cust_pkg',
                                 hashref  => $hashref,
                                 extra_sql => $action_replace,
                                 order_by => 'ORDER BY history_action',
                              });
      }

      next unless scalar(@history) == 2;

      my @new = grep { $_->history_action eq 'replace_new' } @history;
      my @old = grep { $_->history_action eq 'replace_old' } @history;
    
      next if (scalar(@new) == 2 || scalar(@old) == 2);

      $_->date($new[0]->get($field))
        if ( $new[0]->get($field) &&
             ( !$old[0]->get($field) ||
                $old[0]->get($field) != $new[0]->get($field)
             )
           );

      my $error = $_->replace
        if $_->modified;

      die $error if $error;
    }
  }

  #seek cancels/suspends without reason, but with expire/adjourn reason
  foreach my $field qw( cancel susp ) {

    my %precursor_map = ( 'cancel' => 'expire', 'susp' => 'adjourn' );
    my $precursor = $precursor_map{$field};
    my $preaction = uc(substr($precursor,0,1));
    my $action    = uc(substr($field,0,1));
    my $addl_from =
      "LEFT JOIN cust_pkg_reason ON ".
      "(cust_pkg.pkgnum = cust_pkg_reason.pkgnum AND".
      " cust_pkg.$precursor = cust_pkg_reason.date AND".
      " cust_pkg_reason.action = '$preaction') ".
      "LEFT JOIN cust_pkg_reason AS target ON ".
      "(cust_pkg.pkgnum = target.pkgnum AND".
      " cust_pkg.$field = target.date AND".
      " target.action = '$action')"
    ;

    my $extra_sql = "WHERE target.pkgnum IS NULL AND ".
                    "cust_pkg.$field IS NOT NULL AND ".
                    "cust_pkg.$field < cust_pkg.$precursor + 86400 AND ".
                    "cust_pkg_reason.action = '$preaction'";

    my @unmigrated = qsearch({ table     => 'cust_pkg',
                               hashref   => { },
                               select    => 'cust_pkg.*',
                               addl_from => $addl_from,
                               extra_sql => $extra_sql,
                            }); 
    foreach ( @unmigrated ) {
      my $cpr = new FS::cust_pkg_reason { $_->last_cust_pkg_reason($precursor)->hash, 'num' => '' };
      $cpr->date($_->get($field));
      $cpr->action($action);

      my $error = $cpr->insert;
      die $error if $error;
    }
  }

  #still can't fill in an action?  don't abort the upgrade
  local($ignore_empty_action) = 1;

  $class->_upgrade_otaker(%opts);
}

=back

=head1 BUGS

Here be termites.  Don't use on wooden computers.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

