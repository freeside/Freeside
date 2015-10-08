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
voided payment / voided invoice.

=cut

sub reason {
  my $self = shift;

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

  if (   defined dbdef->table($table)->column('reason')
      && defined dbdef->table($table)->column('reasonnum') )
  {

    warn "$me Checking for unmigrated reasons\n" if $DEBUG;

    my @legacy_reason_records = qsearch(
        {
            'table'     => $table,
            'hashref'   => {},
            'extra_sql' => 'WHERE reason IS NOT NULL',
        }
    );

    if (scalar(grep { $_->getfield('reason') =~ /\S/ } @legacy_reason_records)) {
      warn "$me Found unmigrated reasons\n" if $DEBUG;

      my $reason_type = _upgrade_get_legacy_reason_type($class, $table);
      my $noreason = _upgrade_get_no_reason($class, $reason_type);

      foreach my $record_to_upgrade (@legacy_reason_records) {
          my $reason = $record_to_upgrade->getfield('reason');
          warn "Contemplating reason $reason\n" if $DEBUG > 1;
          if ( $reason =~ /\S/ ) {
              my $reason = _upgrade_get_reason( $class, $reason, $reason_type );
              $record_to_upgrade->reasonnum( $reason->reasonnum );
          }
          else {
              $record_to_upgrade->reasonnum( $noreason->reasonnum );
          }

          $record_to_upgrade->setfield( 'reason', '' );
          my $error = $record_to_upgrade->replace;

          my $primary_key = $record_to_upgrade->primary_key;
          warn "*** WARNING: error replacing reason in $class "
            . $record_to_upgrade->get($primary_key)
            . ": $error ***\n"
            if $error;
       }
    }
  }
}

# _upgrade_get_legacy_reason_type is class method supposed to be used only
# within the reason_Mixin class which will either find or create a reason_type
sub _upgrade_get_legacy_reason_type {
 
    my $class = shift;
    my $table = shift;

    my $reason_class =
      ( $table =~ /void/ ) ? 'X' : 'F';    # see FS::reason_type (%class_name)
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
    return _upgrade_get_reason( $class, '(none)', $reason_type );
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
