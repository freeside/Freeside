#!/usr/bin/make

DATASOURCE = DBI:Pg:host=localhost;dbname=freeside
#DATASOURCE=DBI:mysql:freeside

DB_USER = freeside
DB_PASSWORD=

#TEMPLATE = asp
TEMPLATE = mason

ASP_GLOBAL = /usr/local/etc/freeside/asp-global

FREESIDE_DOCUMENT_ROOT = /var/www/freeside

INIT_FILE = /etc/init.d/freeside

HTTPD_RESTART = /etc/init.d/apache restart
FREESIDE_RESTART = /etc/init.d/freeside restart

#---

#not changable yet
FREESIDE_CONF = /usr/local/etc/freeside

VERSION=1.4.0pre12
TAG=freeside_1_4_0_pre12

help:
	@echo "supported targets: aspdocs masondocs alldocs docs install-docs"
	@echo "                   htmlman"
	@echo "                   perl-modules install-perl-modules"
	@echo "                   install deploy"
	@echo "                   create-database"
	@echo "                   clean"

aspdocs: htmlman httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf aspdocs
	cp -pr httemplate aspdocs
	touch aspdocs

masondocs: htmlman httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	( cd masondocs; \
	  ../bin/masonize; \
	)
	touch masondocs

alldocs: aspdocs masondocs

docs:
	make ${TEMPLATE}docs

htmlman:
	[ -e ./httemplate/docs/man ] || mkdir httemplate/docs/man
	[ -e ./httemplate/docs/man/bin ] || mkdir httemplate/docs/man/bin
	[ -e ./httemplate/docs/man/FS ] || mkdir httemplate/docs/man/FS
	[ -e ./httemplate/docs/man/FS/UI ] || mkdir httemplate/docs/man/FS/UI
	[ -e DONT_REBUILD_DOCS ] || bin/pod2x


install-docs: docs
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S` || true
	cp -r ${TEMPLATE}docs ${FREESIDE_DOCUMENT_ROOT}
	[ "${TEMPLATE}" = "asp" -a ! -e ${ASP_GLOBAL} ] && mkdir ${ASP_GLOBAL} || true
	[ "${TEMPLATE}" = "asp" ] && chown -R freeside ${ASP_GLOBAL} || true
	[ "${TEMPLATE}" = "asp" ] && cp htetc/global.asa ${ASP_GLOBAL} || true

perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make

install-perl-modules: perl-modules
	cd FS; \
	make install UNINST=1

install-init:
	[ -e ${INIT_FILE} ] || install -o root -g root -m 711 init.d/freeside-init ${INIT_FILE}

install: install-perl-modules install-docs install-init

deploy: install
	${HTTPD_RESTART}
	${FREESIDE_RESTART}

create-database:
	perl -e 'use DBIx::DataSource qw( create_database ); create_database( "${DATASOURCE}", "${DB_USER}", "${DB_PASSWORD}" ) or die $$DBIx::DataSource::errstr;'

create-config: install-perl-modules
	[ -e ${FREESIDE_CONF} ] && mv ${FREESIDE_CONF} ${FREESIDE_CONF}.`date +%Y%m%d%H%M%S` || true
	mkdir ${FREESIDE_CONF}
	chown freeside ${FREESIDE_CONF}

	touch ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets

	echo -e "${DATASOURCE}\n${DB_USER}\n${DB_PASSWORD}" >${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets

	mkdir "${FREESIDE_CONF}/conf.${DATASOURCE}"
	cp conf/[a-z]* "${FREESIDE_CONF}/conf.${DATASOURCE}"
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

#these are probably only useful if you're me...

upload-docs:
	ssh cleanwhisker.420.am rm -rf /var/www/www.sisd.com/freeside/devdocs
	scp -pr httemplate/docs cleanwhisker.420.am:/var/www/www.sisd.com/freeside/devdocs

release: upload-docs
	cd /home/ivan/freeside_current
	#cvs tag ${TAG}
	cvs tag -F ${TAG}

	cd /home/ivan
	cvs export -r ${TAG} -d freeside-${VERSION} freeside
	tar czvf freeside-${VERSION}.tar.gz freeside-${VERSION}

	scp freeside-${VERSION}.tar.gz ivan@cleanwhisker.420.am:/var/www/sisd.420.am/freeside/

update-webdemo:
	ssh ivan@pouncequick.420.am '( cd freeside; cvs update -d -P )'
	#ssh root@pouncequick.420.am '( cd /home/ivan/freeside; make clean; make deploy )'
	ssh root@pouncequick.420.am '( cd /home/ivan/freeside; make deploy )'

