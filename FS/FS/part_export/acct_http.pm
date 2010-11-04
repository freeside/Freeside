package FS::part_export::acct_http;

use vars qw( @ISA %info );
use FS::part_export::http;
use Tie::IxHash;

@ISA = qw( FS::part_export::http );

tie %options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'url'    => { label   => 'URL', default => 'http://', },
  'insert_data' => {
    label   => 'Insert data',
    type    => 'textarea',
    default => join("\n",
      "action 'add'",
      "username \$svc_x->username",
      "password \$svc_x->_password",
      "prismid \$cust_main->agent_custid ? \$cust_main->agent_custid : \$cust_main->custnum ",
      "name \$cust_main->first.' '.\$cust_main->last",
    ),
  },
  'delete_data' => {
    label   => 'Delete data',
    type    => 'textarea',
    default => join("\n",
      "action  'remove'",
      "username \$svc_x->username",
    ),
  },
  'replace_data' => {
    label   => 'Replace data',
    type    => 'textarea',
    default => join("\n",
      "action  'update'",
      "username \$old->username",
      "password \$new->_password",
    ),
  },
  'success_regexp' => {
    label  => 'Success Regexp',
    default => '',
  },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Send an HTTP or HTTPS GET or POST request, for accounts.',
  'options' => \%options,
  'notes'   => <<'END'
Send an HTTP or HTTPS GET or POST to the specified URL on account addition,
modification and deletion.  For HTTPS support,
<a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a>
is required.
END
);

1;
