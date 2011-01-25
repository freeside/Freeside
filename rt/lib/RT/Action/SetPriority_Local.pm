package RT::Action::SetPriority;
use strict;
no warnings 'redefine';

# Extension to allow relative priority changes:
# if Argument is "R" followed by a value, it's 
# relative to current priority.
sub Commit {
    my $self = shift;
    my ($rel, $val);
    my $arg = $self->Argument;
    if ( $arg ) {
      ($rel, $val) = ( $arg =~ /^(r?)(-?\d+)$/i );
      if (!length($val)) {
        warn "Bad argument to SetPriority: '$arg'\n";
        return 0;
      }
    }
    else {
      my %Rules = $self->Rules;
      $rel = length($Rules{'inc'}) ? 1 : 0;
      $val = $Rules{'inc'} || $Rules{'set'};
      if ($val !~ /^[+-]?\d+$/) {
        warn "Bad argument to SetPriority: '$val'\n";
        return 0;
      }
    }
    $val += $self->TicketObj->Priority if $rel;
    $self->TicketObj->SetPriority($val);
}

sub Options {
  (
    {
      'name'    => 'set',
      'label'   => 'Set to value',
      'type'    => 'text',
    },
    {
      'name'    => 'inc',
      'label'   => 'Increment by',
      'type'    => 'text',
    },
  )
}

1;
