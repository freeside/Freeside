use strict;
use warnings;
no warnings qw(redefine);

package RT::Action::SendEmail;

=head1 DESCRIPTION

Overlay for RT::Action::SendEmail to implement a global email notifications
blacklist.  All components that send email using the SendEmail action will
be affected by this blacklist.

The web interface uses these filters to decide which email addresses to
display as sendable.  This gives us the added bonus of transparency.  If
an e-mail address is blacklisted, it will never appear in the recipient
list on a ticket correspondance.

=head1 USAGE

To enable the blacklist, add a configuration option to RT_SiteConfig.pm

    Set(@NotifyBlacklist,(qw(reddit.com slashdot.org frank)));

If an email address regex matches any item in the list, no email is sent

=head1 DEV NOTE

This overlay implementation will need to be maintained if RT updates
the SendEmail action to filter addresses differently.  The benefit of
using rt overlays is our library changes easily persist between rt versions,
and don't need to be reimplemented with each release of rt.  The downside
of overlays if the underlying rt core functionality changes, our overlay
may break rt until it is removed or updated.

For information on RT library overlays,
see L<https://rt-wiki.bestpractical.com/wiki/CustomizingWithOverlays>

=cut

sub RecipientFilter {
    my $self = shift;

    unless (ref $self->{RecipientFilter}) {
      my @blacklist;
      eval { @blacklist = @RT::NotifyBlacklist };
      if (@blacklist) {
        push @{$self->{RecipientFilter}}, {
          All => 1,
          Callback => sub {
            my $email = shift;
            for my $block (@blacklist) {
              return "$email is blacklisted by NotifyBlacklist, skipping"
                if $email =~ /$block/i;
            }
            return 0;
          }
        };
      }
    }
    push @{ $self->{RecipientFilter}}, {@_};
}

1;
