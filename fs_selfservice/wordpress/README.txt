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

In Wordpress, go to Settings -> General and set "Freeside self-service URL"
to the 


Freeside configuration:

Go to Configuration -> Settings and turn on "selfservice-xmlrpc".  Restart
Freeside services to turn on the daemon ("etc/init.d/freeside restart", or
"service freeside restart")


Firewall/network configuration:

Allow the Wordpress machine to connect to port 8080 on the Freeside machine.
Ensure the connection is on a secure network, or appropriately secured with a
VPN or tunnel.


Usage:

See the included example_login.php, process_login.php and
example_selfservice.php files.  These files perform a self-service login
and display a basic landing page.  To use, copy them to the wordpress content
directory (or a subdirectory), and point your browser to example_login.php

For full API documentation including all available functions, their arguments
and return data, see
http://www.freeside.biz/mediawiki/index.php/Freeside:3:Documentation:Developer/FS/SelfService

