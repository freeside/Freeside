package FS::dbdef_index;

use strict;
use vars qw(@ISA);
use FS::dbdef_colgroup;

@ISA=qw(FS::dbdef_colgroup);

=head1 NAME

FS::dbdef_unique.pm - Index object

=head1 SYNOPSIS

  use FS::dbdef_index;

    # see FS::dbdef_colgroup methods

=head1 DESCRIPTION

FS::dbdef_unique objects represent the (non-unique) indices of a table
(L<FS::dbdef_table>).  FS::dbdef_unique inherits from FS::dbdef_colgroup.

=head1 BUGS

Is this empty subclass needed?

=head1 SEE ALSO

L<FS::dbdef_colgroup>, L<FS::dbdef_record>, L<FS::Record>

=head1 HISTORY

class for dealing with index definitions

ivan@sisd.com 98-apr-19

pod ivan@sisd.com 98-sep-24

=cut

1;

