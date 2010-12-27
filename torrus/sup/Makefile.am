
#  Copyright (C) 2002  Stanislav Sinyagin
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

# $Id: Makefile.am,v 1.1 2010-12-27 00:04:04 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#

dtddir = $(supdir)/dtd
dist_dtd_DATA =  dtd/snmp-discovery.dtd   dtd/torrus-config.dtd

mibsdir = $(supdir)/mibs
dist_mibs_DATA =  mibs/RRDTOOL-SMI.txt \
		  mibs/TORRUS-MIB.txt

styldir = $(supdir)/styling
dist_styl_DATA = \
	styling/colornames.pl  \
	styling/rainbow-schema.pl \
	styling/torrus-schema.pl


webplaindir = @webplaindir@
dist_webplain_DATA = \
	webplain/explain-rrdgraph.html \
	webplain/torrus.css \
	webplain/torrus-printer.css \
	webplain/torrus-report.css


install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(webscriptsdir)
