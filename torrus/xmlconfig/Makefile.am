
#  Copyright (C) 2002-2010  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

# $Id: Makefile.am,v 1.1 2010-12-27 00:04:05 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#

EXTRA_DIST = \
	site-global.xml

xmldir         = $(distxmldir)
dist_xml_DATA  = defaults.xml snmp-defs.xml cdef-collector-defs.xml

vendordir      = $(distxmldir)/vendor
dist_vendor_DATA = \
	vendor/alteon.xml \
	vendor/alu-timetra.xml \
	vendor/apc.ups.xml  \
	vendor/apple.ae.xml \
	vendor/arbor_e.xml \
	vendor/ascend.max.xml \
	vendor/atmel.xml \
	vendor/betternetworks.xml \
	vendor/casa-cmts.xml \
	vendor/cisco.firewall.xml \
	vendor/cisco.generic.xml \
	vendor/cisco.ios.xml \
	vendor/cisco.ios.docsis.xml \
	vendor/cisco.ios.mac-accounting.xml \
	vendor/cisco.sce.xml \
	vendor/cisco.vdsl-line.xml \
	vendor/compaq.cim.xml \
	vendor/empire.systemedge.xml \
	vendor/empire.systemedge.ntregperf.xml \
	vendor/f5.bigip.xml \
	vendor/foundry.xml \
	vendor/ftos.xml \
	vendor/jacarta.xml \
	vendor/junos.xml \
	vendor/hp.hpux.xml \
	vendor/liebert.xml \
	vendor/microsoft.windows.xml \
	vendor/motorola.bsr.xml \
	vendor/netapp.filer.xml \
	vendor/netbotz.xml \
	vendor/netscreen.xml \
	vendor/paradyne.xdsl.xml \
	vendor/symmetricom.xml \
	vendor/ucd.ucd-snmp.xml

genericdir    =  $(distxmldir)/generic
dist_generic_DATA = \
	generic/collector-periods.xml \
	generic/monitors.xml \
	generic/rfc1628.ups.xml \
	generic/rfc1697.rdbms.xml \
	generic/rfc2662.adsl-line.xml \
	generic/rfc2670.docsis-if.xml \
	generic/rfc2790.host-resources.xml \
	generic/rfc2863.if-mib.xml

examplesdir   =  $(distxmldir)/examples
dist_examples_DATA = \
	examples/apc-ups.xml \
	examples/ascend.max.xml \
	examples/docsis-monitors.xml \
	examples/generic-netsnmp.xml \
	examples/hpux.xml \
	examples/monitors.xml \
	examples/multigraph.xml \
	examples/rainbow-schema.xml \
	examples/servers.data \
	examples/servers.tmpl

olddir        =  $(distxmldir)/old
dist_old_DATA = \
	old/cisco.generic.old-0.1.4.xml \
	old/cisco.ios.mac-accounting-0.1.8.xml \
	old/cisco-mac-accounting-example.xml \
	old/rfc1213.xml \
	old/rfc2670.docsis-if.old.0.1.5d-20040224.xml \
	old/rfc2670.docsis-if.old.1.0.4.xml \
	old/rfc2863.if-mib.old-0.1.4.xml \
	old/rfc2863.if-mib.old-0.1.7.xml \
	old/snmp-defs.old-0.1.2.xml


install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(sitexmldir)
	if test ! -r $(DESTDIR)$(sitexmldir)/site-global.xml; then \
	  $(INSTALL_DATA) site-global.xml \
		$(DESTDIR)$(sitexmldir)/site-global.xml; \
	fi


