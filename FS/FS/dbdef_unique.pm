package FS::dbdef_unique;

use strict;
use vars qw(@ISA);
use FS::dbdef_colgroup;

@ISA=qw(FS::dbdef_colgroup);

=head1 NAME

FS::dbdef_unique.pm - Unique object

=head1 SYNOPSIS

  use FS::dbdef_unique;

  # see FS::dbdef_colgroup methods

=head1 DESCRIPTION

FS::dbdef_unique objects represent the unique indices of a database table
(L<FS::dbdef_table>).  FS::dbdef_unique inherits from FS::dbdef_colgroup.

=head1 BUGS

Is this empty subclass needed?

=head1 SEE ALSO

L<FS::dbdef_colgroup>, L<FS::dbdef_record>, L<FS::Record>

=cut

1;


