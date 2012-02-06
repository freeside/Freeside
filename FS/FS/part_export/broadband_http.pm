package FS::part_export::broadband_http;

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
      "address \$svc_x->ip_addr",
      "name \$cust_main->first.' '.\$cust_main->last",
    ),
  },
  'delete_data' => {
    label   => 'Delete data',
    type    => 'textarea',
    default => join("\n",
      "action  'remove'",
      "address \$svc_x->ip_addr",
    ),
  },
  'replace_data' => {
    label   => 'Replace data',
    type    => 'textarea',
    default => '',
  },
  'success_regexp' => {
    label   => 'Success Regexp',
    default => '',
  },
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Send an HTTP or HTTPS GET or POST request, for accounts.',
  'options' => \%options,
  'notes'   => <<'END'
<p>Send an HTTP or HTTPS GET or POST to the specified URL on account addition,
modification and deletion.  For HTTPS support,
<a href="http://search.cpan.org/dist/Crypt-SSLeay">Crypt::SSLeay</a>
or <a href="http://search.cpan.org/dist/IO-Socket-SSL">IO::Socket::SSL</a>
is required.</p>
<p>Each "Data" option takes a list of <i>name value</i> pairs on successive 
lines.
<ul><li><i>name</i> is an unquoted, literal string without whitespace.</li>
<li><i>value</i> is a Perl expression that will be evaluated.  If it's a 
literal string, it must be quoted.  This expression has access to the
svc_broadband object as '$svc_x' (or '$new' and '$old' in "Replace Data") 
and the customer record as '$cust_main'.</li></ul>
If "Success Regexp" is specified, the response from the server will be
tested against it to determine if the export succeeded.</p>
END
);

1;
