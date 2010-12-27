
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

# $Id: Makefile.am,v 1.1 2010-12-27 00:03:37 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#


install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(perllibdir)
	find * -type d ! -name CVS -print >list.tmp
	for d in `cat list.tmp`; do \
	  $(mkinstalldirs) $(DESTDIR)$(perllibdir)/$$d; done
	find * \( -name '*.pm' \) -type f -print >list.tmp
	for f in `cat list.tmp`; do \
	  $(INSTALL_DATA) $$f $(DESTDIR)$(perllibdir)/$$f; done
	rm -f list.tmp


uninstall-local:
	find * -type d ! -name CVS -print >list.tmp
	for d in `cat list.tmp`; do \
	  rm -r $(DESTDIR)$(perllibdir)/$$d; done
	rm -f list.tmp


dist-hook:
	find * -type d ! -name CVS -print >list.tmp
	for d in `cat list.tmp`; do \
	  mkdir $(distdir)/$$d; done
	find * \( -name '*.pm' -o -name '*.txt' \) -type f -print >list.tmp
	for f in `cat list.tmp`; do \
	  cp $$f $(distdir)/$$f; done
	rm -f list.tmp
