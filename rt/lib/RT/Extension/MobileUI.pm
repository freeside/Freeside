use warnings;
use strict;

package RT::Extension::MobileUI;

our $VERSION = "1.01";


=head1 NAME

RT::Extension::MobileUI - A phone friendly web interface for RT

=head1 DESCRIPTION

This RT extension adds a mobile interface for RT.

=head1 INSTALLATION

    # perl Makefile.PL
    # make
    # make install

    Add RT::Extension::MobileUI to your /opt/rt3/etc/RT_SiteConfig.pm file
    Set(@Plugins, qw(RT::Extension::MobileUI));

    If you have more than one Plugin enabled, you must enable them as one 
    Set(@Plugins, qw(Foo Bar)); command

    # restart apache
=cut




sub MobileClient {
    my $self = shift;


if (($ENV{'HTTP_USER_AGENT'} || '') =~ /(?:hiptop|Blazer|Novarra|Vagabond|SonyEricsson|Symbian|NetFront|UP.Browser|UP.Link|Windows CE|MIDP|J2ME|DoCoMo|J-PHONE|PalmOS|PalmSource|iPhone|iPod|AvantGo|Nokia|Android|WebOS|S60|Opera Mini|Opera Mobi)/io && !$HTML::Mason::Commands::session{'NotMobile'})  {
    return 1;
} else {
    return undef;
}

}

=head1 AUTHOR

Jesse Vincent E<lt>jesse@bestpractical.comE<gt>

=head1 LICENSE

GPL version 2.

=cut

1;
