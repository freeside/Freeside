package RT::Transaction;
use strict;
use vars qw(%_BriefDescriptions);

$_BriefDescriptions{'Set'} = sub {
    my $self = shift;
    if ( $self->Field eq 'Password' ) {
        return $self->loc('Password changed');
    }
    elsif ( $self->Field eq 'Queue' ) {
        my $q1 = new RT::Queue( $self->CurrentUser );
        $q1->Load( $self->OldValue );
        my $q2 = new RT::Queue( $self->CurrentUser );
        $q2->Load( $self->NewValue );
        return $self->loc("[_1] changed from [_2] to [_3]",
                          $self->loc($self->Field) , $q1->Name , $q2->Name);
    }

    # Write the date/time change at local time:
    elsif ($self->Field =~  /Due|Starts|Started|Told|WillResolve/) {
        my $t1 = new RT::Date($self->CurrentUser);
        $t1->Set(Format => 'ISO', Value => $self->NewValue);
        my $t2 = new RT::Date($self->CurrentUser);
        $t2->Set(Format => 'ISO', Value => $self->OldValue);
        return $self->loc( "[_1] changed from [_2] to [_3]", $self->loc($self->Field), $t2->AsString, $t1->AsString );
    }
    else {
        return $self->loc( "[_1] changed from [_2] to [_3]",
                           $self->loc($self->Field),
                           ($self->OldValue? "'".$self->OldValue ."'" : $self->loc("(no value)")) , "'". $self->NewValue."'" );
    }
};

1;

