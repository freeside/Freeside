package RT::CustomField;
use strict;
no warnings 'redefine';

sub _VendorAccessible {
    {
        Required => 
                {read => 1, write => 1, sql_type => 5, length => 6, is_blob => 0, is_numeric => 1, type => 'smallint(6)', default => '0'},
    },
};

1;
