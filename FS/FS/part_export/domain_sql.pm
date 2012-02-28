package FS::part_export::domain_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw(%info);
use Tie::IxHash;
use FS::part_export;

tie my %options, 'Tie::IxHash', %{__PACKAGE__->sql_options};

tie my %postfix_transport_map, 'Tie::IxHash', 
  'domain' => 'domain'
;
my $postfix_transport_map = 
  join('\n', map "$_ $postfix_transport_map{$_}",
                 keys %postfix_transport_map      );
tie my %postfix_transport_static, 'Tie::IxHash',
  'transport' => 'virtual:',
;
my $postfix_transport_static = 
  join('\n', map "$_ $postfix_transport_static{$_}",
                 keys %postfix_transport_static      );

%info  = (
  'svc'     => 'svc_domain',
  'desc'    => 'Real time export of domains to SQL databases '.
               '(postfix, others?)',
  'options' => \%options,
  'notes'   => <<END
Export domains (svc_domain records) to SQL databases.  Currently this is a
simple export with a default for Postfix, but it can be extended for other
uses.

<BR><BR>Use these buttons for useful presets:
<UL>
  <LI><INPUT TYPE="button" VALUE="postfix_transport" onClick='
    this.form.table.value = "transport";
    this.form.schema.value = "$postfix_transport_map";
    this.form.static.value = "$postfix_transport_static";
    this.form.primary_key.value = "domain";
  '>
</UL>
END
);

# inherit everything else from sql_Common

1;

