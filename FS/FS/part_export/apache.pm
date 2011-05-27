package FS::part_export::apache;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::null;

@ISA = qw(FS::part_export::null);

tie my %options, 'Tie::IxHash',
  'user'       => { label=>'Remote username', default=>'root' },
  'httpd_conf' => { label=>'httpd.conf snippet location',
                    default=>'/etc/apache/httpd-freeside.conf', },
  'restart'    => { label=>'Apache restart command',
                    default=>'apachectl graceful',
                  },
  'template'   => {
    label   => 'Template',
    type    => 'textarea',
    default => <<'END',
<VirtualHost $zone> #generic
#<VirtualHost ip.addr> #preferred, http://httpd.apache.org/docs/dns-caveats.html
DocumentRoot /var/www/$zone
ServerName $zone
ServerAlias *.$zone
#BandWidthModule On
#LargeFileLimit 4096 12288
#FrontpageEnable on
</VirtualHost>

END
  },
  'template_inactive' => {
    label   => 'Template (when suspended)',
    type    => 'textarea',
    default => <<'END',
<VirtualHost $zone> #generic
#<VirtualHost ip.addr> #preferred, http://httpd.apache.org/docs/dns-caveats.html
DocumentRoot /var/www/$zone
ServerName $zone
ServerAlias *.$zone
#BandWidthModule On
#LargeFileLimit 4096 12288
#FrontpageEnable on
Redirect 402 /
</VirtualHost>

END
  },
;

%info = (
  'svc'     => 'svc_www',
  'desc'    => 'Export an Apache httpd.conf file snippet.',
  'options' => \%options,
  'notes'   => <<'END'
Batch export of an httpd.conf snippet from a template.  Typically used with
something like <code>Include /etc/apache/httpd-freeside.conf</code> in
httpd.conf.  <a href="http://search.cpan.org/dist/File-Rsync">File::Rsync</a>
must be installed.  Run bin/apache.export to export the files.
END
);

1;

