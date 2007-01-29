#!/usr/bin/make

#solaris and perhaps other very weirdass /bin/sh
#SHELL="/bin/ksh"

DATASOURCE = DBI:Pg:dbname=freeside
#DATASOURCE=DBI:mysql:freeside

DB_USER = freeside
DB_PASSWORD=

#changable now (some things which should go to the others still go to CONF)
FREESIDE_CONF = /usr/local/etc/freeside
FREESIDE_LOG = /usr/local/etc/freeside
FREESIDE_LOCK = /usr/local/etc/freeside
FREESIDE_CACHE = /usr/local/etc/freeside
FREESIDE_EXPORT = /usr/local/etc/freeside

MASON_HANDLER = ${FREESIDE_CONF}/handler.pl
MASONDATA = ${FREESIDE_CACHE}/masondata

#mod_perl v1
APACHE_VERSION = 1
#mod_perl v2 prereleases up to and including 1.999_21
#APACHE_VERSON = 1.99
#mod_perl v2 proper and prereleases 1.999_22 and after
#APACHE_VERSION = 2

# only mason now
TEMPLATE = mason

#deb
FREESIDE_DOCUMENT_ROOT = /var/www/freeside
#redhat, fedora, mandrake
#FREESIDE_DOCUMENT_ROOT = /var/www/html/freeside
#freebsd
#FREESIDE_DOCUMENT_ROOT = /usr/local/www/data/freeside
#openbsd
#FREESIDE_DOCUMENT_ROOT = /var/www/htdocs/freeside
#suse
#FREESIDE_DOCUMENT_ROOT = /srv/www/htdocs/freeside
#apache
#FREESIDE_DOCUMENT_ROOT = /usr/local/apache/htdocs/freeside

#deb, redhat, fedora, mandrake, suse, others?
INIT_FILE = /etc/init.d/freeside
#freebsd
#INIT_FILE = /usr/local/etc/rc.d/011.freeside.sh

#deb
INIT_INSTALL = /usr/sbin/update-rc.d freeside defaults 21 20
#redhat, fedora
#INIT_INSTALL = /sbin/chkconfig freeside on
#not necessary (freebsd)
#INIT_INSTALL = /usr/bin/true

#deb, suse
HTTPD_RESTART = /etc/init.d/apache restart
#redhat, fedora, mandrake
#HTTPD_RESTART = /etc/init.d/httpd restart
#freebsd
#HTTPD_RESTART = /usr/local/etc/rc.d/apache.sh stop || true; sleep 10; /usr/local/etc/rc.d/apache.sh start
#openbsd
#HTTPD_RESTART = kill -TERM `cat /var/www/logs/httpd.pid`; sleep 10; /usr/sbin/httpd -u -DSSL
#apache
#HTTPD_RESTART = /usr/local/apache/bin/apachectl stop; sleep 10; /usr/local/apache/bin/apachectl startssl

#(an include directory, not a file - "Include /etc/apache/conf.d" in httpd.conf)
#deb (3.1+), 
APACHE_CONF = /etc/apache/conf.d

FREESIDE_RESTART = ${INIT_FILE} restart

#deb, redhat, fedora, mandrake, suse, others?
INSTALLGROUP = root
#freebsd, openbsd
#INSTALLGROUP = wheel

#edit the stuff below to have the daemons start

QUEUED_USER=fs_queue

SELFSERVICE_USER = fs_selfservice
#never run on the same machine in production!!!
SELFSERVICE_MACHINES = localhost
# SELFSERVICE_MACHINES = www.example.com
# SELFSERVICE_MACHINES = web1.example.com web2.example.com

#user with sudo access on SELFSERVICE_MACHINES for automated self-service
#installation.
SELFSERVICE_INSTALL_USER = ivan
SELFSERVICE_INSTALL_USERADD = /usr/sbin/useradd
#SELFSERVICE_INSTALL_USERADD = "/usr/sbin/pw useradd"

#RT_ENABLED = 0
RT_ENABLED = 1
RT_DOMAIN = example.com
RT_TIMEZONE = US/Pacific
#RT_TIMEZONE = US/Eastern
FREESIDE_URL = "http://localhost/freeside/"

#for now, same db as specified in DATASOURCE... eventually, otherwise?
RT_DB_DATABASE = freeside

#---


#rt/config.layout.in
RT_PATH = /opt/rt3

#only used for dev kludge now, not a big deal
FREESIDE_PATH = `pwd`
PERL_INC_DEV_KLUDGE = /usr/local/share/perl/5.8.8/

VERSION=1.7.2
TAG=freeside_1_7_2

help:
	@echo "supported targets:"
	@echo "                   create-database create-config"
	@echo "                   install deploy"
	@echo "                   configure-rt create-rt"
	@echo "                   clean help"
	@echo
	@echo "                   install-docs install-perl-modules"
	@echo "                   install-init install-apache"
	@echo "                   install-rt"
	@echo "                   install-selfservice update-selfservice"
	@echo
	@echo "                   dev dev-docs dev-perl-modules"
	@echo
	@echo "                   masondocs alldocs docs"
	@echo "                   htmlman forcehtmlman"
	@echo "                   perl-modules"
	#@echo
	#@echo "                   upload-docs release update-webdemo"


#masondocs: htmlman httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
masondocs: htmlman httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	touch masondocs

alldocs: masondocs

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
	chown -R freeside:freeside ${FREESIDE_DOCUMENT_ROOT}
	cp htetc/handler.pl ${MASON_HANDLER}
	  perl -p -i -e "\
	    s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g; \
	    s'%%%RT_ENABLED%%%'${RT_ENABLED}'g; \
	    s'%%%MASONDATA%%%'${MASONDATA}'g;\
	  " ${MASON_HANDLER}
	[ ! -e ${MASONDATA} ] && mkdir ${MASONDATA} || true
	chown -R freeside ${MASONDATA}

dev-docs:
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S` || true
	ln -s ${FREESIDE_PATH}/httemplate ${FREESIDE_DOCUMENT_ROOT}
	cp htetc/handler.pl ${MASON_HANDLER}
	perl -p -i -e "\
	  s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g; \
	  s'%%%RT_ENABLED%%%'${RT_ENABLED}'g; \
	  s'%%%MASONDATA%%%'${MASONDATA}'g;\
	  s'###use Module::Refresh;###'use Module::Refresh;'; \
	  s'###Module::Refresh->refresh;###'Module::Refresh->refresh;'; \
	" ${MASON_HANDLER} || true


perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make; \
	perl -p -i -e "\
	  s/%%%VERSION%%%/${VERSION}/g;\
	" blib/lib/FS.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_CONF%%%|${FREESIDE_CONF}|g;\
	" blib/lib/FS/*.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_EXPORT%%%|${FREESIDE_EXPORT}|g;\
	" blib/lib/FS/part_export/*.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_CONF%%%|${FREESIDE_CONF}|g;\
	  s|%%%FREESIDE_LOG%%%|${FREESIDE_LOG}|g;\
	  s|%%%FREESIDE_LOCK%%%|${FREESIDE_LOCK}|g;\
	  s|%%%FREESIDE_CACHE%%%|${FREESIDE_CACHE}|g;\
	  s|%%%FREESIDE_EXPORT%%%|${FREESIDE_EXPORT}|g;\
	" blib/script/*

install-perl-modules: perl-modules
	[ -L ${PERL_INC_DEV_KLUDGE}/FS ] \
	  && rm ${PERL_INC_DEV_KLUDGE}/FS \
	  && mv ${PERL_INC_DEV_KLUDGE}/FS.old ${PERL_INC_DEV_KLUDGE}/FS \
	  || true
	cd FS; \
	make install UNINST=1

dev-perl-modules: perl-modules
	[ -d ${PERL_INC_DEV_KLUDGE}/FS -a ! -L ${PERL_INC_DEV_KLUDGE}/FS ] \
	  && mv ${PERL_INC_DEV_KLUDGE}/FS ${PERL_INC_DEV_KLUDGE}/FS.old \
	  || true

	rm -rf ${PERL_INC_DEV_KLUDGE}/FS
	ln -sf ${FREESIDE_PATH}/FS/blib/lib/FS ${PERL_INC_DEV_KLUDGE}/FS

install-init:
	#[ -e ${INIT_FILE} ] || install -o root -g ${INSTALLGROUP} -m 711 init.d/freeside-init ${INIT_FILE}
	install -o root -g ${INSTALLGROUP} -m 711 init.d/freeside-init ${INIT_FILE}
	perl -p -i -e "\
	  s/%%%QUEUED_USER%%%/${QUEUED_USER}/g;\
	  s/%%%SELFSERVICE_USER%%%/${SELFSERVICE_USER}/g;\
	  s/%%%SELFSERVICE_MACHINES%%%/${SELFSERVICE_MACHINES}/g;\
	" ${INIT_FILE}
	${INIT_INSTALL}

install-apache:
	[ -e ${APACHE_CONF}/freeside-base.conf ] && rm ${APACHE_CONF}/freeside-base.conf || true
	[ -d ${APACHE_CONF} ] && \
	  ( install -o root -m 755 htetc/freeside-base${APACHE_VERSION}.conf ${APACHE_CONF} && \
	    ( [ ${RT_ENABLED} -eq 1 ] && install -o root -m 755 htetc/freeside-rt.conf ${APACHE_CONF} || true ) && \
	    perl -p -i -e "\
	      s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g; \
	      s'%%%MASON_HANDLER%%%'${MASON_HANDLER}'g; \
	    " ${APACHE_CONF}/freeside-*.conf \
	  ) || true

install-selfservice:
	[ -e ~freeside/.ssh/id_dsa.pub ] || su - freeside -c 'ssh-keygen -t dsa'
	for MACHINE in ${SELFSERVICE_MACHINES}; do \
	  scp -r fs_selfservice/FS-SelfService ${SELFSERVICE_INSTALL_USER}@$$MACHINE:. ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; perl Makefile.PL && make" ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; sudo make install" ;\
	  scp ~freeside/.ssh/id_dsa.pub ${SELFSERVICE_INSTALL_USER}@$$MACHINE:. ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "sudo ${SELFSERVICE_INSTALL_USERADD} freeside; sudo install -d -o freeside -m 600 ~freeside/.ssh/" ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "sudo ${SELFSERVICE_INSTALL_USERADD} freeside; sudo install -o freeside -m 600 ./id_dsa.pub ~freeside/.ssh/authorized_keys" ;\
	   ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "sudo install -o freeside -d /usr/local/freeside" ;\
	done

update-selfservice:
	for MACHINE in ${SELFSERVICE_MACHINES}; do \
	  RSYNC_RSH=ssh rsync -rlptz fs_selfservice/FS-SelfService/ ${SELFSERVICE_INSTALL_USER}@$$MACHINE:FS-SelfService ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; perl Makefile.PL && make" ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; sudo make install" ;\
	done

install: install-perl-modules install-docs install-init install-apache install-rt

deploy: install
	${HTTPD_RESTART}
	${FREESIDE_RESTART}

dev: dev-perl-modules dev-docs

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

	mkdir "${FREESIDE_CACHE}/counters.${DATASOURCE}"
	chown freeside "${FREESIDE_CACHE}/counters.${DATASOURCE}"

	mkdir "${FREESIDE_CACHE}/cache.${DATASOURCE}"
	chown freeside "${FREESIDE_CACHE}/cache.${DATASOURCE}"

	mkdir "${FREESIDE_EXPORT}/export.${DATASOURCE}"
	chown freeside "${FREESIDE_EXPORT}/export.${DATASOURCE}"

configure-rt:
	cd rt; \
	cp config.layout.in config.layout; \
	perl -p -i -e "\
	  s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g;\
	  s'%%%MASONDATA%%%'${MASONDATA}'g;\
	" config.layout; \
	./configure --enable-layout=Freeside\
	            --with-db-type=Pg \
	            --with-db-dba=${DB_USER} \
	            --with-db-database=${RT_DB_DATABASE} \
	            --with-db-rt-user=${DB_USER} \
	            --with-db-rt-pass=${DB_PASSWORD} \
	            --with-web-user=freeside \
	            --with-web-group=freeside \
	            --with-rt-group=freeside

create-rt: configure-rt
	[ -d /opt           ] || mkdir /opt           #doh
	[ -d /opt/rt3       ] || mkdir /opt/rt3       #
	[ -d /opt/rt3/share ] || mkdir /opt/rt3/share #
	cd rt; make install
	echo -e "${DB_PASSWORD}\n\\d sessions"\
	 | psql -U ${DB_USER} -W ${RT_DB_DATABASE} 2>&1\
	 | grep '^Did not find'\
	 && rt/sbin/rt-setup-database --dba '${DB_USER}' \
	                             --dba-password '${DB_PASSWORD}' \
	                             --action schema \
	 || true
	rt/sbin/rt-setup-database --action insert_initial \
	&& rt/sbin/rt-setup-database --action insert --datafile ${RT_PATH}/etc/initialdata \
	|| true
	perl -p -i -e "\
	  s'%%%RT_DOMAIN%%%'${RT_DOMAIN}'g;\
	  s'%%%RT_TIMEZONE%%%'${RT_TIMEZONE}'g;\
	  s'%%%FREESIDE_URL%%%'${FREESIDE_URL}'g;\
	" ${RT_PATH}/etc/RT_SiteConfig.pm

install-rt:
	[ ${RT_ENABLED} -eq 1 ] && ( cd rt; make install ) || true

clean:
	rm -rf masondocs
	rm -rf httemplate/docs/man
	rm -rf pod2htmi.tmp
	rm -rf pod2htmd.tmp
	-cd FS; \
	make clean
	-cd fs_selfservice/FS-SelfService; \
	make clean

#these are probably only useful if you're me...

upload-docs: forcehtmlman
	ssh 420.am rm -rf /var/www/www.sisd.com/freeside/docs
	scp -pr httemplate/docs 420.am:/var/www/www.sisd.com/freeside/docs

#release: upload-docs
release:
	cd /home/ivan/freeside
	#cvs tag ${TAG}
	cvs tag -F ${TAG}

	#cd /home/ivan
	cvs export -r ${TAG} -d freeside-${VERSION} freeside
	tar czvf freeside-${VERSION}.tar.gz freeside-${VERSION}

	scp freeside-${VERSION}.tar.gz ivan@420.am:/var/www/www.sisd.com/freeside/
	mv freeside-${VERSION} freeside-${VERSION}.tar.gz ..

update-webdemo:
	ssh ivan@420.am '( cd freeside; cvs update -d -P )'
	#ssh root@420.am '( cd /home/ivan/freeside; make clean; make deploy )'
	ssh root@420.am '( cd /home/ivan/freeside; make deploy )'

