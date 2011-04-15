package RT::Extension::SearchResults::XLS;

use warnings;
use strict;

=head1 NAME

RT::Extension::SearchResults::XLS - Add Excel format export to RT search results

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.06';


=head1 SYNOPSIS

This RT Extension allow users to download search results in Microsoft Excel
binary format. This typically fix encoding problems for non-ascii chars with
the standard TSV export included in RT.

=head1 AUTHOR

Emmanuel Lacour, C<< <elacour at home-dn.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rt-extension-searchresults-xls at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RT-Extension-SearchResults-XLS>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RT::Extension::SearchResults::XLS


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RT-Extension-SearchResults-XLS>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RT-Extension-SearchResults-XLS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RT-Extension-SearchResults-XLS>

=item * Search CPAN

L<http://search.cpan.org/dist/RT-Extension-SearchResults-XLS>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008-2010 Emmanuel Lacour, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Request Tracker (RT) is Copyright Best Practical Solutions, LLC.

=cut

1; # End of RT::Extension::SearchResults::XLS
