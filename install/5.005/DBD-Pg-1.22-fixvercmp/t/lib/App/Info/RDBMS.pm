package App::Info::RDBMS;

# $Id: RDBMS.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $

use strict;
use App::Info;
use vars qw(@ISA $VERSION);
@ISA = qw(App::Info);
$VERSION = '0.22';

1;
__END__

=head1 NAME

App::Info::RDBMS - Information about databases on a system

=head1 DESCRIPTION

This class is an abstract base class for App::Info subclasses that provide
information about relational databases. Its subclasses are required to
implement its interface. See L<App::Info|App::Info> for a complete description
and L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL> for an example
implementation.

=head1 INTERFACE

Currently, App::Info::RDBMS adds no more methods than those from its parent
class, App::Info.

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

L<App::Info|App::Info>,
L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut



