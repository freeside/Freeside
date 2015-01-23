package FS::reason_Mixin;

use strict;
use Carp qw( croak ); #confess );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::access_user;
use FS::UID qw( dbh );
use FS::reason;

our $DEBUG = 0;
our $me = '[FS::reason_Mixin]';

=item reason

Returns the text of the associated reason (see L<FS::reason>) for this credit.

=cut

sub reason {
  my ($self, $value, %options) = @_;
  my $reason_text;
  if ( $self->reasonnum ) {
    my $reason = FS::reason->by_key($self->reasonnum);
    $reason_text = $reason->reason;
  } else { # in case one of these somehow still exists
    $reason_text = $self->get('reason');
  }
  if ( $self->get('addlinfo') ) {
    $reason_text .= ' ' . $self->get('addlinfo');
  }

  return $reason_text;
}

# it was a mistake to allow setting the reason this way; use 
# FS::reason->new_or_existing
 
# Used by FS::Upgrade to migrate reason text fields to reasonnum.
sub _upgrade_reasonnum {  # class method
  my $class = shift;
  my $table = $class->table;

  if (defined dbdef->table($table)->column('reason')) {

    warn "$me Checking for unmigrated reasons\n" if $DEBUG;

    my @cust_refunds = qsearch({ 'table'     => $table,
                                 'hashref'   => {},
                                 'extra_sql' => 'WHERE reason IS NOT NULL',
                              });

    if (scalar(grep { $_->getfield('reason') =~ /\S/ } @cust_refunds)) {
      warn "$me Found unmigrated reasons\n" if $DEBUG;
      my $hashref = { 'class' => 'F', 'type' => 'Legacy' };
      my $reason_type = qsearchs( 'reason_type', $hashref );
      unless ($reason_type) {
        $reason_type  = new FS::reason_type( $hashref );
        my $error   = $reason_type->insert();
        die "$class had error inserting FS::reason_type into database: $error\n"
          if $error;
      }

      $hashref = { 'reason_type' => $reason_type->typenum,
                   'reason' => '(none)'
                 };
      my $noreason = qsearchs( 'reason', $hashref );
      unless ($noreason) {
        $hashref->{'disabled'} = 'Y';
        $noreason = new FS::reason( $hashref );
        my $error  = $noreason->insert();
        die "can't insert legacy reason '(none)' into database: $error\n"
          if $error;
      }

      foreach my $cust_refund ( @cust_refunds ) {
        my $reason = $cust_refund->getfield('reason');
        warn "Contemplating reason $reason\n" if $DEBUG > 1;
        if ($reason =~ /\S/) {
          $cust_refund->reason($reason, 'reason_type' => $reason_type->typenum)
            or die "can't insert legacy reason $reason into database\n";
        }else{
          $cust_refund->reasonnum($noreason->reasonnum);
        }

        $cust_refund->setfield('reason', '');
        my $error = $cust_refund->replace;

        warn "*** WARNING: error replacing reason in $class ".
             $cust_refund->refundnum. ": $error ***\n"
          if $error;
      }
    }
  }
}

1;
