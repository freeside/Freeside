
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

# $Id: Makefile.am,v 1.1 2010-12-27 00:04:01 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#

SUBST = @abs_top_builddir@/setup_tools/substvars.sh

pkgbindir = @pkgbindir@
pkgbin_SCRIPTS = \
	acledit                 \
	action_notify    	\
	action_printemail    	\
	action_snmptrap      	\
	action_snmpv1trap    	\
	bdbinfo			\
	buildsearchdb		\
	cleanup   		\
	clearcache   		\
	collector    		\
	compilexml   		\
	configinfo		\
	configsnapshot		\
	devdiscover		\
	flushmonitors		\
	genddx			\
	genlist			\
	genreport		\
	install_plugin		\
	monitor      		\
	nodeid			\
	rrddir2xml		\
	schedulerinfo		\
	snmpfailures		\
	srvderive		\
	torrus.fcgi		\
	ttproclist

wrapperdir = @wrapperdir@
wrapper_SCRIPTS = \
	torrus

CLEANFILES = $(pkgbin_SCRIPTS) $(wrapper_SCRIPTS)

EXTRA_DIST = \
	acledit.in              \
	action_notify.in	\
	action_printemail.in    \
	action_snmptrap.in      \
	action_snmpv1trap.in    \
	bdbinfo.in		\
	buildsearchdb.in	\
	clearcache.in   	\
	cleanup.in		\
	collector.in    	\
	compilexml.in   	\
	configinfo.in		\
	configsnapshot.in	\
	devdiscover.in		\
	flushmonitors.in	\
	genddx.in		\
	genlist.in		\
	genreport.in		\
	install_plugin.in	\
	monitor.in      	\
	nodeid.in		\
	rrddir2xml.in		\
	schedulerinfo.in	\
	snmpfailures.in		\
	srvderive.in		\
	torrus.fcgi.in		\
	torrus.in		\
	ttproclist.in


# Result of:
# ls -1 | egrep '^[a-z][^.]+$' | \
# awk '{printf "%s: %s.in\n\t$(SUBST) %s.in > %s\n\n", $1, $1, $1, $1}'

acledit: acledit.in
	$(SUBST) acledit.in > acledit

action_printemail: action_printemail.in
	$(SUBST) action_printemail.in > action_printemail

action_notify: action_notify.in
	$(SUBST) action_notify.in > action_notify

action_snmptrap: action_snmptrap.in
	$(SUBST) action_snmptrap.in > action_snmptrap

action_snmpv1trap: action_snmpv1trap.in
	$(SUBST) action_snmpv1trap.in > action_snmpv1trap

buildsearchdb: buildsearchdb.in
	$(SUBST) buildsearchdb.in > buildsearchdb

bdbinfo: bdbinfo.in
	$(SUBST) bdbinfo.in > bdbinfo

cleanup: cleanup.in
	$(SUBST) cleanup.in > cleanup

clearcache: clearcache.in
	$(SUBST) clearcache.in > clearcache

collector: collector.in
	$(SUBST) collector.in > collector

compilexml: compilexml.in
	$(SUBST) compilexml.in > compilexml

configinfo: configinfo.in
	$(SUBST) configinfo.in > configinfo

configsnapshot: configsnapshot.in
	$(SUBST) configsnapshot.in > configsnapshot

devdiscover: devdiscover.in
	$(SUBST) devdiscover.in > devdiscover

flushmonitors: flushmonitors.in
	$(SUBST) flushmonitors.in > flushmonitors

genddx: genddx.in
	$(SUBST) genddx.in > genddx

genlist: genlist.in
	$(SUBST) genlist.in > genlist

genreport: genreport.in
	$(SUBST) genreport.in > genreport

install_plugin: install_plugin.in
	$(SUBST) install_plugin.in > install_plugin

monitor: monitor.in
	$(SUBST) monitor.in > monitor

nodeid: nodeid.in
	$(SUBST) nodeid.in > nodeid

rrddir2xml: rrddir2xml.in
	$(SUBST) rrddir2xml.in > rrddir2xml

schedulerinfo: schedulerinfo.in
	$(SUBST) schedulerinfo.in > schedulerinfo

snmpfailures: snmpfailures.in
	$(SUBST) snmpfailures.in > snmpfailures

srvderive: srvderive.in
	$(SUBST) srvderive.in > srvderive

torrus: torrus.in
	$(SUBST) torrus.in > torrus

torrus.fcgi: torrus.fcgi.in
	$(SUBST) torrus.fcgi.in > torrus.fcgi

ttproclist: ttproclist.in
	$(SUBST) ttproclist.in > ttproclist
