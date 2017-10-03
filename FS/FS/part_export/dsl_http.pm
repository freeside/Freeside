package FS::part_export::dsl_http;
use base qw( FS::part_export::http );

use Tie::IxHash;

tie our %options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'url'    => { label   => 'URL', default => 'http://', },
  'ssl_no_verify' => { label => 'Skip SSL certificate validation',
                       type  => 'checkbox',
                     },
  'insert_data' => {
    label   => 'Insert data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'delete_data' => {
    label   => 'Delete data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'replace_data' => {
    label   => 'Replace data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'suspend_data' => {
    label   => 'Suspend data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'unsuspend_data' => {
    label   => 'Unsuspend data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'success_regexp' => {
    label  => 'Success Regexp',
    default => '',
  },
;

%info = (
  'svc'     => 'svc_dsl',
  'desc'    => 'Send an HTTP or HTTPS GET or POST request, for DSL services.',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
Send an HTTP or HTTPS GET or POST to the specified URL on account addition,
modification and deletion.
<p>Each "Data" option takes a list of <i>name value</i> pairs on successive 
lines.
<ul><li><i>name</i> is an unquoted, literal string without whitespace.</li>
<li><i>value</i> is a Perl expression that will be evaluated.  If it's a 
literal string, it must be quoted.  This expression has access to the
svc_dsl object as '$svc_x' (or '$new' and '$old' in "Replace Data") 
and the customer record as '$cust_main'.</li></ul>
If "Success Regexp" is specified, the response from the server will be
tested against it to determine if the export succeeded.</p>
END
);

1;
