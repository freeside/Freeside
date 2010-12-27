
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

# $Id: Makefile.am,v 1.1 2010-12-27 00:04:38 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#

SUBST = @abs_top_builddir@/setup_tools/substvars.sh

EXTRA_DIST = $(SRCPOD)
CLEANFILES = $(PODMAN) $(POD_FILES)

SRCPOD = \
	torrus.pod.in \
	torrus_acledit.pod.in \
	torrus_action_notify.pod.in \
	torrus_action_printemail.pod.in \
	torrus_action_snmptrap.pod.in \
	torrus_buildsearchdb.pod.in \
	torrus_cleanup.pod.in \
	torrus_clearcache.pod.in \
	torrus_collector.pod.in \
	torrus_compilexml.pod.in \
	torrus_configinfo.pod.in \
	torrus_configsnapshot.pod.in \
	torrus_devdiscover.pod.in \
	torrus_flushmonitors.pod.in \
	torrus_genddx.pod.in \
	torrus_genlist.pod.in \
	torrus_genreport.pod.in \
	torrus_install_plugin.pod.in \
	torrus_monitor.pod.in \
	torrus_nodeid.pod.in \
	torrus_rrddir2xml.pod.in \
	torrus_schedulerinfo.pod.in \
	torrus_snmpfailures.pod.in \
	torrus_srvderive.pod.in \
	torrus_ttproclist.pod.in

POD_FILES = \
	torrus.pod \
	torrus_acledit.pod \
	torrus_action_notify.pod \
	torrus_action_printemail.pod \
	torrus_action_snmptrap.pod \
	torrus_buildsearchdb.pod \
	torrus_cleanup.pod \
	torrus_clearcache.pod \
	torrus_collector.pod \
	torrus_compilexml.pod \
	torrus_configinfo.pod \
	torrus_configsnapshot.pod \
	torrus_devdiscover.pod \
	torrus_flushmonitors.pod \
	torrus_genddx.pod \
	torrus_genlist.pod \
	torrus_genreport.pod \
	torrus_install_plugin.pod \
	torrus_monitor.pod \
	torrus_nodeid.pod \
	torrus_rrddir2xml.pod \
	torrus_schedulerinfo.pod \
	torrus_snmpfailures.pod \
	torrus_srvderive.pod \
	torrus_ttproclist.pod

PODMAN = \
	torrus.@mansec_usercmd@ \
	torrus_acledit.@mansec_usercmd@ \
	torrus_action_notify.@mansec_misc@ \
	torrus_action_printemail.@mansec_misc@ \
	torrus_action_snmptrap.@mansec_misc@ \
	torrus_buildsearchdb.@mansec_usercmd@ \
	torrus_cleanup.@mansec_usercmd@ \
	torrus_clearcache.@mansec_usercmd@ \
	torrus_collector.@mansec_usercmd@ \
	torrus_compilexml.@mansec_usercmd@ \
	torrus_configinfo.@mansec_usercmd@ \
	torrus_configsnapshot.@mansec_usercmd@ \
	torrus_devdiscover.@mansec_usercmd@ \
	torrus_flushmonitors.@mansec_usercmd@ \
	torrus_genddx.@mansec_usercmd@ \
	torrus_genlist.@mansec_usercmd@ \
	torrus_genreport.@mansec_usercmd@ \
	torrus_install_plugin.@mansec_misc@ \
	torrus_monitor.@mansec_usercmd@ \
	torrus_nodeid.@mansec_usercmd@ \
	torrus_rrddir2xml.@mansec_usercmd@ \
	torrus_schedulerinfo.@mansec_usercmd@ \
	torrus_snmpfailures.@mansec_usercmd@ \
	torrus_srvderive.@mansec_usercmd@ \
	torrus_ttproclist.@mansec_usercmd@



if POD2MAN_PRESENT
install-data-local: $(POD_FILES)
	for f in $(PODMAN); do \
	  base=`echo $$f | sed -e 's/\\.[0-9a-zA-Z]*$$//'`; \
	  ext=`echo $$f | sed -e 's/^.*\\.//'`; \
	  instdir=$(DESTDIR)$(mandir)/man$$ext; \
	  echo BASE=$$base EXT=$$ext INSTDIR=$$instdir; \
	  $(POD2MAN) --section=$$ext \
	     --release="$(PACKAGE_STRING)" --center=torrus \
             $$base.pod > $$f || exit 1; \
	  test -d $$instdir || $(mkinstalldirs) $$instdir || exit 1; \
	  $(INSTALL_DATA) $$f $$instdir; \
	  rm $$f; \
	done
endif


SUFFIXES = .pod.in .pod

.PRECIOUS: $(POD_FILES)

.pod.in.pod:
	$(SUBST) $<  > $@

pods: $(POD_FILES)
