package RT::Action::SetWillResolve;
use base 'RT::Action';

use strict;

sub Describe  {
  my $self = shift;
  return (ref $self ." will set a ticket's future resolve date to the argument.");
}

sub Prepare {
    my $self = shift;
    my $DateObj = RT::Date->new( $self->CurrentUser );
    if ( length($self->Argument) ) {
        $DateObj->Set(
            Format => 'unknown',
            Value  => $self->Argument
        )
    }
    else { # special case: treat Argument => '' as "never"
        $DateObj->Unix(-1);
    }
    $self->{new_value} = $DateObj->ISO;
    # if the before and after values are string-equivalent, don't bother
    return ($DateObj->AsString ne $self->TicketObj->WillResolveAsString);
}

sub Commit {
    my $self = shift;
    $self->TicketObj->SetWillResolve( $self->{new_value} );
}

RT::Base->_ImportOverlays();

1;
