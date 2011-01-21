# backport from RT4 RT::SharedSettings

package RT::SavedSearches;

use strict;
no warnings 'redefine';

sub CountAll {
    my $self = shift;
    return $self->Count;
}

sub GotoPage {
    my $self = shift;
    $self->{idx} = shift;
}

1;

