package RT::Action::SetWillResolve;
use base 'RT::Action';

use strict;

sub Describe  {
  my $self = shift;
  return (ref $self ." will set a ticket's future resolve date to the argument.");
}

sub Prepare  {
    return 1;
}

sub Commit {
    my $self = shift;
    my $DateObj = RT::Date->new( $self->CurrentUser );
    $DateObj->Set(
      Format => 'unknown', 
      Value  => $self->Argument,
    );
    $self->TicketObj->SetWillResolve( $DateObj->ISO );
}

RT::Base->_ImportOverlays();

1;
