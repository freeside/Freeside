package RTx::WebCronTool;
$RTx::WebCronTool::VERSION = "0.01";

1;

__END__

=head1 NAME

RTx::WebCronTool - Web interface to rt-crontool

=head1 VERSION

This document describes version 0.01 of RTx::WebCronTool, released
July 11, 2004.

=head1 DESCRIPTION

This RT extension provides a web interface for the built-in F<rt-crontool>
utility, allowing scheduled processes to be launched remotely.

After installation, log in as superuser, and click on the "Web CronTool" menu
on the bottom of the navigation pane.

To use it, simply submit the modules and arguments.  All progress, error messages
and debug information will then be displayed online.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
