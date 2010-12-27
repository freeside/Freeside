# Torrus Site config. Put all your site specifics here.
# You need to stop and start Apache server every time you change this file.

@Torrus::Global::xmlAlwaysIncludeFirst = ( 'defaults.xml', 'site-global.xml' );

%Torrus::Global::treeConfig =
    (
     'main' => {
         'description' => 'The main tree',
         'info'        => 'main tree', #'some tree', #per-agent?
         'xmlfiles' => [qw(routers.xml)],
         'run' => { 'collector' => 1, 'monitor' => 0 } }
     );

# Customizable look in the HTML page top
# $Torrus::Renderer::companyName = 'Your company name';
# $Torrus::Renderer::companyURL = 'http://torrus.sf.net';
# $Torrus::Renderer::siteInfo = `hostname`;

#Freeside
$Torrus::CGI::authorizeUsers = 0;
$Torrus::Renderer::rendererURL = '/freeside/torrus';
$Torrus::Renderer::plainURL    = '/freeside/torrus/plain/';
$Torrus::Renderer::Freeside::FSURL = '%%%FREESIDE_URL%%%';

1;
