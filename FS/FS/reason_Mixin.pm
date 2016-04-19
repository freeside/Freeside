package FS::reason_Mixin;

use strict;
use Carp qw( croak ); #confess );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::access_user;
use FS::UID qw( dbh );
use FS::reason;
use FS::reason_type;

our $DEBUG = 0;
our $me = '[FS::reason_Mixin]';

=item reason

Returns the text of the associated reason (see L<FS::reason>) for this credit /
voided payment / voided invoice. This can no longer be used to set the
(deprecated) free-text "reason" field; see L<FS::reason/new_or_existing>.

=cut

sub reason {
  my $self = shift;

  my $reason_text = $self->reason_only;

  if ( $self->get('addlinfo') ) {
    $reason_text .= ' ' . $self->get('addlinfo');
  }

  return $reason_text;
}

=item reason_only

Returns only the text of the associated reason,
absent any addlinfo that is included by L</reason>.
(Currently only affects credit and credit void reasons.)

=cut

# a bit awkward, but much easier to invoke this in the few reports
# that need separate fields than to update every place
# that displays them together

sub reason_only {
  my $self = shift;
  if ( $self->reasonnum ) {
    my $reason = FS::reason->by_key($self->reasonnum);
    return $reason->reason;
  } else { # in case one of these somehow still exists
    return $self->get('reason');
  }
}

# Used by FS::Upgrade to migrate reason text fields to reasonnum.
# Note that any new tables that get reasonnum fields do NOT need to be
# added here unless they have previously had a free-text "reason" field.

sub _upgrade_reasonnum {    # class method
    my $class = shift;
    my $table = $class->table;

    my $reason_class;
    if ( $table =~ /^cust_bill/ ) { # also includes cust_bill_pkg
      $reason_class = 'I';
    } elsif ( $table =~ /^cust_pay/ ) {
      $reason_class = 'P';
    } elsif ( $table eq 'cust_refund' ) {
      $reason_class = 'F';
    } elsif ( $table =~ /^cust_credit/ ) {
      $reason_class = 'R';
    } else {
      die "don't know the reason class to use for upgrading $table";
    }

    for my $fieldname (qw(reason void_reason)) {

        if ( $table =~ /^cust_credit/ and $fieldname eq 'void_reason' ) {
            $reason_class = 'X';
        }

        if (   defined dbdef->table($table)->column($fieldname)
            && defined dbdef->table($table)->column( $fieldname . 'num' ) )
        {

            warn "$me Checking for unmigrated reasons\n" if $DEBUG;

            my @legacy_reason_records = qsearch(
                {
                    'table'     => $table,
                    'hashref'   => {},
                    'extra_sql' => 'WHERE ' . $fieldname . ' IS NOT NULL',
                }
            );

            if ( @legacy_reason_records ) {

                warn "$me Found unmigrated reasons\n" if $DEBUG;

                my $reason_type =
                  $class->_upgrade_get_legacy_reason_type( $reason_class );
                # XXX "noreason" does not actually work, because we limited to
                # "reason is not null" above. Records where the reason string
                # is null will end up with a reasonnum of null also.
                my $noreason = $class->_upgrade_get_no_reason( $reason_type );

                foreach my $record_to_upgrade (@legacy_reason_records) {
                    my $reason = $record_to_upgrade->getfield($fieldname);
                    warn "Contemplating reason $reason\n" if $DEBUG > 1;
                    if ( $reason =~ /\S/ ) {
                        my $reason =
                          $class->_upgrade_get_reason( $reason, $reason_type );
                        $record_to_upgrade->set( $fieldname . 'num',
                            $reason->reasonnum );
                    }
                    else {
                        $record_to_upgrade->set( $fieldname . 'num',
                            $noreason->reasonnum );
                    }

                    $record_to_upgrade->setfield( $fieldname, '' );
                    my $error = $record_to_upgrade->replace;

                    my $primary_key = $record_to_upgrade->primary_key;
                    warn "*** WARNING: error replacing $fieldname in $class "
                      . $record_to_upgrade->get($primary_key)
                      . ": $error ***\n"
                      if $error;
                }
            }
        }
    }
}

# internal methods for upgrade

# _upgrade_get_legacy_reason_type is class method supposed to be used only
# within the reason_Mixin class which will either find or create a reason_type
sub _upgrade_get_legacy_reason_type {
 
    my $class = shift;
    my $reason_class = shift;
    my $reason_type_params = { 'class' => $reason_class, 'type' => 'Legacy' };
    my $reason_type = qsearchs( 'reason_type', $reason_type_params );
    unless ($reason_type) {
        $reason_type = new FS::reason_type($reason_type_params);
        my $error = $reason_type->insert();
        die "$class had error inserting FS::reason_type into database: $error\n"
           if $error;
    }
    return $reason_type;
}

# _upgrade_get_no_reason is class method supposed to be used only within the
# reason_Mixin class which will either find or create a default (no reason)
# reason
sub _upgrade_get_no_reason {

    my $class       = shift;
    my $reason_type = shift;
    return $class->_upgrade_get_reason( '(none)', $reason_type );
}

# _upgrade_get_reason is class method supposed to be used only within the
# reason_Mixin class which will either find or create a reason
sub _upgrade_get_reason {

    my $class       = shift;
    my $reason_text = shift;
    my $reason_type = shift;

    my $reason_params = {
        'reason_type' => $reason_type->typenum,
        'reason'      => $reason_text
    };
    my $reason = qsearchs( 'reason', $reason_params );
    unless ($reason) {
        $reason_params->{'disabled'} = 'Y';
        $reason = new FS::reason($reason_params);
        my $error = $reason->insert();
        die "can't insert legacy reason '$reason_text' into database: $error\n"
           if $error;
     }
    return $reason;
}

1;
