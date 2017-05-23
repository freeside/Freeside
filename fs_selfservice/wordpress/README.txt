Freeside signup and self-service plugin for Wordpress


Installation:

Copy this directory to your Wordpress plugins directory
(For example, /var/lib/wordpress/wp-content/plugins/freeside/)

Make sure the PHP XMLRPC module is installed
(for example, "apt-get install php-xmlrpc")


Activation:

In Wordpress, go to Plugins -> Installed Plugins, find the "Freeside signup and
self-service" plugin, and click "Activate".


Configuration:

In Wordpress, go to Settings -> General and set "Freeside server"
to your Freeside server name or IP address.


Freeside configuration:

Go to Configuration -> Settings and turn on "selfservice-xmlrpc".  Restart
Freeside services to turn on the daemon ("etc/init.d/freeside restart", or
"service freeside restart")


Freeside self-service:

If you are using signup or additional package order with the API-provided
package selection HTML (as in the services_new.php example), make sure the
regular Freeside self-service is installed on the same server as the wordpress
site.  Make sure the Freeside configuration setting
"selfservice_server-base_url" is correct and matches the hostname used to
access the site, including https:// if using (which you certainly should!).


Firewall/network configuration:

Allow the Wordpress machine to connect to port 8080 on the Freeside machine.
Ensure the connection is on a secure network, or appropriately secured with a
VPN or tunnel.


Usage:

See the included example_login.php, process_login.php, process_login.php,
example_selfservice.php and view_invoice.php files.  These files perform a
self-service login and display a basic landing page.  To use, copy them and
the elements/ subdirectory to the wordpress content directory (or a
subdirectory) and point your browser to example_login.php

For full API documentation including all available functions, their arguments
and return data, see
http://www.freeside.biz/mediawiki/index.php/Freeside:3:Documentation:Developer/FS/SelfService

