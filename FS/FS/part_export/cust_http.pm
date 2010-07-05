package FS::part_export::cust_http;

use vars qw( @ISA %info );
use FS::part_export::http;
use Tie::IxHash;

@ISA = qw( FS::part_export::http );

tie my %options, 'Tie::IxHash', %FS::part_export::http::options;

$options{'insert_data'}->{'default'} = join("\n",
  "action  'insert'",
  "custnum \$cust_main->custnum",
  "first   \$cust_main->first",
  "last    \$cust_main->get('last')",
  ( map "$_ \$cust_main->$_", qw( company address1 address2 city county state zip country daytime night fax  last ) ),
  "email   \$cust_main->invoicing_list_emailonly_scalar",
);
$options{'delete_data'}->{'default'} = join("\n",
  "action  'delete'",
  "custnum \$cust_main->custnum",
);
$options{'replace_data'}->{'default'} = join("\n",
  "action  'replace'",
  "custnum \$new_cust_main->custnum",
  "first   \$new_cust_main->first",
  "last    \$new_cust_main->get('last')",
  ( map "$_ \$cust_main->$_", qw( company address1 address2 city county state zip country daytime night fax  last ) ),
  "email   \$new_cust_main->invoicing_list_emailonly_scalar",
);

%info = (
  'svc'     => 'cust_main',
  'desc'    => 'Send an HTTP or HTTPS GET or POST request, for customers.',
  'options' => \%options,
  'notes'   => <<'END'
Send an HTTP or HTTPS GET or POST to the specified URL on customer addition,
modification and deletion.  For HTTPS support,
<a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a>
is required.
END
);

1;
