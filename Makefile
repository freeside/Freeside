#!/usr/bin/make

#Pg
DATASOURCE = DBI:Pg:host=localhost;dbname=freeside
#pgsql on some systems; check /etc/passwd
DB_ADMIN_USER = postgres
DB_ADMIN_PASSWORD=

#mysql
#DATASOURCE=DBI:mysql:freeside
#DB_ADMIN_USER=mysql
#DB_ADMIN_PASSWORD=

TEMPLATE = asp
#mason's a bit dodgy stil
#TEMPLATE = mason

FREESIDE_DOCUMENT_ROOT = /var/www/freeside

#---

#not changable yet
FREESIDE_CONF = /usr/local/etc/freeside

help:
	@echo "supported targets: aspdocs masondocs alldocs docs install-docs"
	@echo "                   perl-modules install-perl-modules"
	@echo "                   install deploy"
	@echo "                   create-database"
	@echo "                   clean"

aspdocs: httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf aspdocs
	cp -pr httemplate aspdocs
	touch aspdocs

masondocs: httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	( cd masondocs; \
	  ../bin/masonize; \
	)
	touch masondocs

alldocs: aspdocs masondocs

docs:
	make ${TEMPLATE}docs

install-docs: docs
	cp -r ${TEMPLATE}docs ${FREESIDE_DOCUMENT_ROOT}

perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make

install-perl-modules: perl-modules
	cd FS; \
	make install

install: install-perl-modules install-docs

deploy: install
	/etc/init.d/apache restart

create-database:
	perl -e 'use DBIx::DataSource qw( create_database ); create_database( \'${DATASOURCE}\', \'${DB_ADMIN_USER}\', \'${DB_ADMIN_PASSWORD}\' ) or die $DBIx::DataSource::errstr;'

create-config: install-perl-modules
	[ -d ${FREESIDE_CONF} ] || mkdir ${FREESIDE_CONF}
	chown freeside ${FREESIDE_CONF}

	[ -d "${FREESIDE_CONF}/conf.${DATASOURCE}" ] \
	  || mkdir "${FREESIDE_CONF}/conf.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF/conf.${DATASOURCE}"

	[ -d "${FREESIDE_CONF}/counters.${DATASOURCE}" ] \
	  || mkdir "${FREESIDE_CONF}/counters.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF/counters.${DATASOURCE}"

	[ -d "${FREESIDE_CONF}/cache.${DATASOURCE}" ] \
	  || mkdir "${FREESIDE_CONF}/cache.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF/cache.${DATASOURCE}"

	[ -d "${FREESIDE_CONF}/export.${DATASOURCE}" ] \
	  || mkdir "${FREESIDE_CONF}/export.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF/export.${DATASOURCE}"

clean:
	rm -rf aspdocs masondocs
	cd FS; \
	make clean

