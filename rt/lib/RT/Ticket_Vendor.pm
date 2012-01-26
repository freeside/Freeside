package RT::Ticket;
use strict;

sub SetPriority {
  # Special case: Pass a value starting with 'R' to set priority 
  # relative to the current level.  Used for bulk updates, though 
  # it can be used anywhere else too.
  my $Ticket = shift;
  my $value = shift;
  if ( $value =~ /^R([+-]?\d+)$/ ) {
    $value = $1 + ($Ticket->Priority || 0);
  }
  $Ticket->SUPER::SetPriority($value);
}

=head2 Touch

Creates a Touch transaction (a null transaction).  Like Comment and 
Correspond but without any content.

=cut

sub Touch {
    my $self = shift;
    my %args = (
        TimeTaken => 0,
        ActivateScrips => 1,
        CommitScrips => 1,
        CustomFields => {},
        @_
    );
    unless ( $self->CurrentUserHasRight('ModifyTicket')
              or $self->CurrentUserHasRight('CommentOnTicket')
              or $self->CurrentUserHasRight('ReplyToTicket')) {
        return ( 0, $self->loc("Permission Denied"));
    }
    $self->_NewTransaction(
        Type => 'Touch',
        TimeTaken => $args{'TimeTaken'},
        ActivateScrips => $args{'ActivateScrips'},
        CommitScrips => $args{'CommitScrips'},
        CustomFields => $args{'CustomFields'},
    );
}


=head2 MissingRequiredFields {

Return all custom fields with the Required flag set for which this object
doesn't have any non-empty values.

=cut

sub MissingRequiredFields {
    my $self = shift;
    my $CustomFields = $self->CustomFields;
    my @results;
    while ( my $CF = $CustomFields->Next ) {
        next if !$CF->Required;
        if ( !length($self->FirstCustomFieldValue($CF->Id) || '') )  {
            push @results, $CF;
        }
    }
    return @results;
}

# Declare the 'WillResolve' field
sub _VendorAccessible {
    {
        WillResolve =>
        {read => 1, write => 1, sql_type => 11, length => 0, is_blob => 0, is_numeric => 0, type => 'datetime', default => ''},
    },
};

sub WillResolveObj {
  my $self = shift;

  my $time = new RT::Date( $self->CurrentUser );

  if ( my $willresolve = $self->WillResolve ) {
    $time->Set( Format => 'sql', Value => $willresolve );
  }
  else {
    $time->Set( Format => 'unix', Value => -1 );
  }

  return $time;
}

sub WillResolveAsString {
  my $self = shift;
  return $self->WillResolveObj->AsString();
}


1;
