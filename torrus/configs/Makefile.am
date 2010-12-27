
#  Copyright (C) 2004  Stanislav Sinyagin
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

# $Id: Makefile.am,v 1.1 2010-12-27 00:04:41 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#

EXTRA_DIST = \
	devdiscover-config.pl \
	devdiscover-siteconfig.pl \
	email-siteconfig.pl \
	initscript.conf \
	notify-siteconfig.pl \
	snmptrap-siteconfig.pl \
	torrus-config.pl \
	torrus-siteconfig.pl \
	webmux.pl \
	webmux2.pl

DISTCLEANFILES = instvars

instvarsdir = $(cfgdefdir)
nodist_instvars_DATA = instvars

install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(cfgdefdir) $(DESTDIR)$(siteconfdir)
	for f in initscript.conf devdiscover-config.pl torrus-config.pl \
		webmux.pl webmux2.pl; do \
	  @abs_top_builddir@/setup_tools/substvars.sh $$f > \
		$(DESTDIR)$(cfgdefdir)/$$f; \
	done
	for f in devdiscover-siteconfig.pl email-siteconfig.pl \
		 notify-siteconfig.pl \
	         snmptrap-siteconfig.pl torrus-siteconfig.pl; do \
	  if test ! -r $(DESTDIR)$(siteconfdir)/$$f; then \
	    $(INSTALL_DATA) $$f $(DESTDIR)$(siteconfdir)/$$f; \
	  fi \
	done
