use warnings;
use strict;

package RT::Extension::ExtractCustomFieldValues;

=head1 NAME

RT::Extension::ExtractCustomFieldValues - extract CF values from email headers or body

=cut

our $VERSION = '3.07';

1;

=head1 DESCRIPTION

ExtractCustomFieldValues is based on a scrip action
"ExtractCustomFieldValues", which can be used to scan incoming emails
to set values of custom fields.

=head1 INSTALLATION

    perl Makefile.PL
    make
    make install
    make initdb # first time only, not on upgrades

When using this extension with RT 3.8, you will need to add
extension to the Plugins configuration:

    Set( @Plugins, qw(... RT::Extension::ExtractCustomFieldValues) );

If you are upgrading this extension from 3.05 or earlier, you will
need to read the UPGRADING file after running make install to add 
the new Scrip Action.

=head1 USAGE

To use the ScripAction, create a Template and a Scrip in RT.
Your new Scrip should use a ScripAction of 'Extract Custom Field Values'.
The Template consists of the lines which control the scanner. All
non-comment lines are of the following format:

    <cf-name>|<Headername>|<MatchString>|<Postcmd>|<Options>

where:

=over 4

=item <cf-name> - the name of a custom field (must be created in RT) If this
field is blank, the match will be run and Postcmd will be executed, but no
custom field will be updated. Use this if you need to execute other RT code
based on your match.

=item <Headername> - either a Name of an email header, "body" to scan the body
of the email or "headers" to search all of the headers.

=item <MatchString> - a regular expression to find a match in the header or
body if the MatchString matches a comma separated list and the CF is a multi
value CF then each item in the list is added as a separate value.

=item <Postcmd>  - a perl code to be evaluated on C<$value>, where C<$value> is
either $1 or full match text from the match performed with <MatchString>

=item <Options> - a string of letters which may control some aspects.  Possible
options include:

=over 4

=item 'q' - (quiet) Don't record a transaction when adding the custom field value

=item '*' - (wildcard) The MatchString regex should contain _two_ capturing
groups, the first of which is the CF name, the second of which is the value.
If this option is given, the <cf-name> field is ignored.

=back

=back

=head2 Separator

You can change the separator string (initially "\|") during the
template with:

    Separator=<anyregexp>

Changing the separator may be necessary, if you want to use a "|" in
one of the patterns in the controlling lines.

=head2 Example and further reading

An example template with some further examples is installed during
"make install" or "make insert-template". See the
CustomFieldScannerExample template for examples and further
documentation.

=head1 AUTHOR

This extension was originally written by Dirk Pape
E<lt>pape@inf.fu-berlin.deE<gt>.

This version is modified by Best Practical for customer use
and maintained by Best Practical Solutions.

=head1 BUGS

Report bugs using L<http://rt.cpan.org> service, discuss on RT's
mailing lists, see also L</SUPPORT>

=head1 SUPPORT

Support requests should be referred to Best Practical
E<lt>sales@bestpractical.comE<gt>.  

=cut
