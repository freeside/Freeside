#!/usr/bin/make

DATASOURCE = DBI:Pg:host=localhost;dbname=freeside
#DATASOURCE=DBI:mysql:freeside

DB_USER = freeside
DB_PASSWORD=

TEMPLATE = asp
#mason's a bit dodgy still
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
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S`
	cp -r ${TEMPLATE}docs ${FREESIDE_DOCUMENT_ROOT}

perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make

install-perl-modules: perl-modules
	cd FS; \
	make install UNINST=1

install: install-perl-modules install-docs

deploy: install
	/etc/init.d/apache restart

create-database:
	perl -e 'use DBIx::DataSource qw( create_database ); create_database( \'${DATASOURCE}\', \'${DB_USER}\', \'${DB_PASSWORD}\' ) or die $DBIx::DataSource::errstr;'

create-config: install-perl-modules
	[ -e ${FREESIDE_CONF} ] || mv ${FREESIDE_CONF} ${FREESIDE_CONF}.`date +%Y%m%d%H%M%S`
	mkdir ${FREESIDE_CONF}
	chown freeside ${FREESIDE_CONF}

	touch ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets

	echo -e "${DATASOURCE}\n${DB_USER}\n${DB_PASSWORD}" >${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets

	mkdir "${FREESIDE_CONF}/conf.${DATASOURCE}"
	cp conf/* "${FREESIDE_CONF}/conf.${DATASOURCE}"
	chown -R freeside "${FREESIDE_CONF}/conf.${DATASOURCE}"

	mkdir "${FREESIDE_CONF}/counters.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF}/counters.${DATASOURCE}"

	mkdir "${FREESIDE_CONF}/cache.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF}/cache.${DATASOURCE}"

	mkdir "${FREESIDE_CONF}/export.${DATASOURCE}"
	chown freeside "${FREESIDE_CONF}/export.${DATASOURCE}"

clean:
	rm -rf aspdocs masondocs
	cd FS; \
	make clean

