#!/usr/bin/make

DATASOURCE = DBI:Pg:dbname=freeside
#DATASOURCE=DBI:mysql:freeside

DB_USER = freeside
DB_PASSWORD=

#TEMPLATE = asp
TEMPLATE = mason

ASP_GLOBAL = /usr/local/etc/freeside/asp-global
MASON_HANDLER = /usr/local/etc/freeside/handler.pl
MASONDATA = /usr/local/etc/freeside/masondata

#deb
FREESIDE_DOCUMENT_ROOT = /var/www/freeside
#redhat, mandrake
#FREESIDE_DOCUMENT_ROOT = /var/www/html/freeside
#freebsd
#FREESIDE_DOCUMENT_ROOT = /usr/local/www/data/freeside
#openbsd
#FREESIDE_DOCUMENT_ROOT = /var/www/htdocs/freeside

#deb, redhat, mandrake, others?
INIT_FILE = /etc/init.d/freeside
#freebsd
#INIT_FILE = /usr/local/etc/rc.d/011.freeside.sh

#deb
HTTPD_RESTART = /etc/init.d/apache restart
#redhat, mandrake
#HTTPD_RESTART = /etc/init.d/httpd restart
#freebsd
#HTTPD_RESTART = /usr/local/etc/rc.d/apache.sh stop; sleep 1; /usr/local/etc/rc.d/apache.sh start
#openbsd
#HTTPD_RESTART = kill -TERM `cat /var/www/logs/httpd.pid`; sleep 1; /usr/sbin/httpd -u -DSSL

FREESIDE_RESTART = ${INIT_FILE} restart

#deb, redhat, mandrake, others?
INSTALLGROUP = root
#freebsd, openbsd
#INSTALLGROUP = wheel

#edit the stuff below to have the daemons start

QUEUED_USER=fs_queue

#eventually this shouldn't be needed
FREESIDE_PATH = `pwd`

SELFSERVICE_USER = fs_selfservice
SELFSERVICE_MACHINES = localhost
# SELFSERVICE_MACHINES = web1.example.com web2.example.com

#---

#not changable yet
FREESIDE_CONF = /usr/local/etc/freeside

VERSION=1.5.0pre4
TAG=freeside_1_5_0pre4

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
	perl -p -i -e "\
	  s/%%%VERSION%%%/${VERSION}/g;\
	" aspdocs/index.html
	touch aspdocs


masondocs: htmlman httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	( cd masondocs; \
	  ../bin/masonize; \
	)
	perl -p -i -e "\
	  s/%%%VERSION%%%/${VERSION}/g;\
	" masondocs/index.html
	touch masondocs

alldocs: aspdocs masondocs

docs:
	make ${TEMPLATE}docs

htmlman:
	[ -e ./httemplate/docs/man ] || mkdir httemplate/docs/man
	[ -e ./httemplate/docs/man/bin ] || mkdir httemplate/docs/man/bin
	[ -e ./httemplate/docs/man/FS ] || mkdir httemplate/docs/man/FS
	[ -e ./httemplate/docs/man/FS/UI ] || mkdir httemplate/docs/man/FS/UI
	[ -e ./httemplate/docs/man/FS/part_export ] || mkdir httemplate/docs/man/FS/part_export
	chmod a+rx bin/pod2x
	[ -e DONT_REBUILD_DOCS ] || bin/pod2x

forcehtmlman:
	[ -e ./httemplate/docs/man ] || mkdir httemplate/docs/man
	[ -e ./httemplate/docs/man/bin ] || mkdir httemplate/docs/man/bin
	[ -e ./httemplate/docs/man/FS ] || mkdir httemplate/docs/man/FS
	[ -e ./httemplate/docs/man/FS/UI ] || mkdir httemplate/docs/man/FS/UI
	[ -e ./httemplate/docs/man/FS/part_export ] || mkdir httemplate/docs/man/FS/part_export
	bin/pod2x

install-docs: docs
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S` || true
	cp -r ${TEMPLATE}docs ${FREESIDE_DOCUMENT_ROOT}
	[ "${TEMPLATE}" = "asp" -a ! -e ${ASP_GLOBAL} ] && mkdir ${ASP_GLOBAL} || true
	[ "${TEMPLATE}" = "asp" ] && chown -R freeside ${ASP_GLOBAL} || true
	[ "${TEMPLATE}" = "asp" ] && cp htetc/global.asa ${ASP_GLOBAL} || true
	[ "${TEMPLATE}" = "mason" ] && cp htetc/handler.pl ${MASON_HANDLER} || true
	[ "${TEMPLATE}" = "mason" -a ! -e ${MASONDATA} ] && mkdir ${MASONDATA} || true
	[ "${TEMPLATE}" = "mason" ] && chown -R freeside ${MASONDATA} || true

perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make

install-perl-modules: perl-modules
	cd FS; \
	make install UNINST=1

install-init:
	#[ -e ${INIT_FILE} ] || install -o root -g ${INSTALLGROUP} -m 711 init.d/freeside-init ${INIT_FILE}
	install -o root -g ${INSTALLGROUP} -m 711 init.d/freeside-init ${INIT_FILE}
	perl -p -i -e "\
	  s/%%%QUEUED_USER%%%/${QUEUED_USER}/g;\
	  s'%%%FREESIDE_PATH%%%'${FREESIDE_PATH}'g;\
	  s/%%%SELFSERVICE_USER%%%/${SELFSERVICE_USER}/g;\
	  s/%%%SELFSERVICE_MACHINES%%%/${SELFSERVICE_MACHINES}/g;\
	" ${INIT_FILE}

install: install-perl-modules install-docs install-init

deploy: install
	${HTTPD_RESTART}
	${FREESIDE_RESTART}

create-database:
	perl -e 'use DBIx::DataSource qw( create_database ); create_database( "${DATASOURCE}", "${DB_USER}", "${DB_PASSWORD}" ) or die $$DBIx::DataSource::errstr;'

create-config: install-perl-modules
	[ -e ${FREESIDE_CONF} ] && mv ${FREESIDE_CONF} ${FREESIDE_CONF}.`date +%Y%m%d%H%M%S` || true
	install -d -o freeside ${FREESIDE_CONF}

	touch ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets

	echo -e "${DATASOURCE}\n${DB_USER}\n${DB_PASSWORD}" >${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets

	mkdir "${FREESIDE_CONF}/conf.${DATASOURCE}"
	rm -rf conf/registries #old dirs just won't go away
	#cp conf/[a-z]* "${FREESIDE_CONF}/conf.${DATASOURCE}"
	cp `ls -d conf/[a-z]* | grep -v CVS` "${FREESIDE_CONF}/conf.${DATASOURCE}"
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

upload-docs: forcehtmlman
	ssh pouncequick.420.am rm -rf /var/www/www.sisd.com/freeside/devdocs
	scp -pr httemplate/docs pouncequick.420.am:/var/www/www.sisd.com/freeside/devdocs

release: upload-docs
	cd /home/ivan/freeside
	#cvs tag ${TAG}
	cvs tag -F ${TAG}

	#cd /home/ivan
	cvs export -r ${TAG} -d freeside-${VERSION} freeside
	tar czvf freeside-${VERSION}.tar.gz freeside-${VERSION}

	scp freeside-${VERSION}.tar.gz ivan@pouncequick.420.am:/var/www/sisd.420.am/freeside/
	mv freeside-${VERSION} freeside-${VERSION}.tar.gz ..

update-webdemo:
	ssh ivan@pouncequick.420.am '( cd freeside; cvs update -d -P )'
	#ssh root@pouncequick.420.am '( cd /home/ivan/freeside; make clean; make deploy )'
	ssh root@pouncequick.420.am '( cd /home/ivan/freeside; make deploy )'

