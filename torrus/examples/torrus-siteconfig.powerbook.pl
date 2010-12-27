# Torrus Site config. Put all your site specifics here.
# You need to stop and start Apache server every time you change this file.
#
# An example using the rainbow-schema overlay.
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>
#
# (ssinyagin) You can use statements like these from inside your
# XML configurations:
#   <include filename="generic/rfc2790.host-resources.xml"/>
# Besides, "devdiscover" discovery tool will soon support most
# of these vendor definitions.

# $Id: torrus-siteconfig.powerbook.pl,v 1.1 2010-12-27 00:04:40 ivan Exp $
# @(#) 10/18/03 torrus-siteconfig.pl 1.3 (10/18/03 18:44:31) sferry

@Torrus::Global::xmlAlwaysIncludeFirst =
    qw(
       defaults.xml
       snmp-defs.xml
       collector-periods.xml
       vendor/cisco.ios.xml
       generic/rfc2790.host-resources.xml
       generic/rfc1213.xml
       vendor/ucd-snmp.xml
    );

%Torrus::Global::treeConfig =
    (
    'powerbook' => {
            'description' => 'Powerbook Laptop Tree',
            'xmlfiles' => [qw(
                    powerbook/powerbook-defaults.xml
                    powerbook/powerbook-ti.xml
                    )],
            'run' => {
                    'collector' => 1,
                    }
            },

     ); # CLOSE %Torrus::Global::treeConfig


     # Override values in the current schema with those in
     # rainbow schema, schema changes require an apache restart
     $Torrus::Renderer::stylingProfileOverlay = "rainbow-schema";


1;
