#!/usr/bin/make

#solaris and perhaps other very weirdass /bin/sh
#SHELL="/bin/ksh"

DB_TYPE = Pg
#DB_TYPE = mysql

DB_USER = freeside
DB_PASSWORD=

DATASOURCE = DBI:${DB_TYPE}:dbname=freeside

#changable now (some things which should go to the others still go to CONF)
FREESIDE_CONF = /usr/local/etc/freeside
FREESIDE_LOG = /usr/local/etc/freeside
FREESIDE_LOCK = /usr/local/etc/freeside
FREESIDE_CACHE = /usr/local/etc/freeside
FREESIDE_EXPORT = /usr/local/etc/freeside

MASON_HANDLER = ${FREESIDE_CONF}/handler.pl
MASONDATA = ${FREESIDE_CACHE}/masondata

#where to put the default configuraiton used by freeside-setup to initialize
#a new database (not used after that).  primarily of interest to distro
#package maintainers
DIST_CONF = ${FREESIDE_CONF}/default_conf

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
INIT_INSTALL = PATH=$PATH:/sbin /usr/sbin/update-rc.d freeside defaults 23 01
#redhat, fedora
#INIT_INSTALL = /sbin/chkconfig freeside on
#not necessary (freebsd)
#INIT_INSTALL = /usr/bin/true

#deb, suse
#HTTPD_RESTART = /etc/init.d/apache restart
#deb w/apache2
HTTPD_RESTART = /etc/init.d/apache2 restart
#redhat, fedora, mandrake
#HTTPD_RESTART = /etc/init.d/httpd restart
#freebsd
#HTTPD_RESTART = /usr/local/etc/rc.d/apache.sh stop || true; sleep 10; /usr/local/etc/rc.d/apache.sh start
#openbsd
#HTTPD_RESTART = kill -TERM `cat /var/www/logs/httpd.pid`; sleep 10; /usr/sbin/httpd -u -DSSL
#apache
#HTTPD_RESTART = /usr/local/apache/bin/apachectl stop; sleep 10; /usr/local/apache/bin/apachectl startssl

#(an include directory, not a file, "Include /etc/apache/conf.d" in httpd.conf)
#deb (3.1+), apache2
APACHE_CONF = /etc/apache2/conf.d

FREESIDE_RESTART = ${INIT_FILE} restart

#deb, redhat, fedora, mandrake, suse, others?
INSTALLGROUP = root
#freebsd, openbsd
#INSTALLGROUP = wheel

#edit the stuff below to have the daemons start

QUEUED_USER=fs_queue

SELFSERVICE_USER = fs_selfservice
#never run on the same machine in production!!!
SELFSERVICE_MACHINES = 
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

TORRUS_ENABLED = 0

# for auto-version updates, so we can "make release" more things automatically
RPM_SPECFILE = rpm/freeside.spec

#---

#rt/config.layout.in
RT_PATH = /opt/rt3

#only used for dev kludge now, not a big deal
FREESIDE_PATH = `pwd`
PERL_INC_DEV_KLUDGE = /usr/local/share/perl/5.10.1/

VERSION=2.3.2
TAG=freeside_2_3_2

DEBVERSION = `echo ${VERSION} | perl -pe 's/(\d)([a-z])/\1~\2/'`-1

TEXMFHOME := "\$$TEXMFHOME"

help:
	@echo "supported targets:"
	@echo "                   create-database create-config"
	@echo "                   install deploy"
	@echo "                   configure-rt create-rt"
	@echo "                   clean help"
	@echo
	@echo "                   install-docs install-perl-modules"
	@echo "                   install-init install-apache"
	@echo "                   install-rt install-texmf"
	@echo "                   install-selfservice update-selfservice"
	@echo
	@echo "                   dev dev-docs dev-perl-modules"
	@echo
	@echo "                   masondocs alldocs docs"
	@echo "                   wikiman"
	@echo "                   perl-modules"
	#@echo
	#@echo "                   upload-docs release"


masondocs: httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	touch masondocs

alldocs: masondocs

docs:
	make masondocs

wikiman:
	chmod a+rx ./bin/pod2x
	./bin/pod2x

install-docs: check-conflicts docs
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S` || true
	cp -r masondocs ${FREESIDE_DOCUMENT_ROOT}
	chown -R freeside:freeside ${FREESIDE_DOCUMENT_ROOT}
	cp htetc/handler.pl ${MASON_HANDLER}
	cp htetc/htpasswd.logout ${FREESIDE_CONF}
	[ ! -e ${MASONDATA} ] && mkdir ${MASONDATA} || true
	chown -R freeside ${MASONDATA}

dev-docs:
	[ -e ${FREESIDE_DOCUMENT_ROOT} ] && mv ${FREESIDE_DOCUMENT_ROOT} ${FREESIDE_DOCUMENT_ROOT}.`date +%Y%m%d%H%M%S` || true
	ln -s ${FREESIDE_PATH}/httemplate ${FREESIDE_DOCUMENT_ROOT}
	cp htetc/handler.pl ${MASON_HANDLER}
	perl -p -i -e "\
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
	  s|%%%FREESIDE_CACHE%%%|${FREESIDE_CACHE}|g;\
	  s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g; \
	  s'%%%RT_ENABLED%%%'${RT_ENABLED}'g; \
	  s'%%%RT_PATH%%%'${RT_PATH}'g; \
	  s'%%%MASONDATA%%%'${MASONDATA}'g;\
	  s/%%%SELFSERVICE_USER%%%/${SELFSERVICE_USER}/g;\
	" blib/lib/FS/*.pm;\
	perl -p -i -e "\
	  s/%%%SELFSERVICE_USER%%%/${SELFSERVICE_USER}/g;\
	  s/%%%SELFSERVICE_MACHINES%%%/${SELFSERVICE_MACHINES}/g;\
	  s|%%%FREESIDE_EXPORT%%%|${FREESIDE_EXPORT}|g;\
	" blib/lib/FS/Cron/*.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_CONF%%%|${FREESIDE_CONF}|g;\
	  s|%%%FREESIDE_EXPORT%%%|${FREESIDE_EXPORT}|g;\
	  s|%%%FREESIDE_LOG%%%|${FREESIDE_LOG}|g;\
	" blib/lib/FS/part_export/*.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_CACHE%%%|${FREESIDE_CACHE}|g;\
	" blib/lib/FS/cust_main/*.pm blib/lib/FS/cust_pkg/*.pm;\
	perl -p -i -e "\
	  s|%%%FREESIDE_CONF%%%|${FREESIDE_CONF}|g;\
	  s|%%%FREESIDE_LOG%%%|${FREESIDE_LOG}|g;\
	  s|%%%FREESIDE_LOCK%%%|${FREESIDE_LOCK}|g;\
	  s|%%%FREESIDE_CACHE%%%|${FREESIDE_CACHE}|g;\
	  s|%%%FREESIDE_EXPORT%%%|${FREESIDE_EXPORT}|g;\
	  s|%%%DIST_CONF%%%|${DIST_CONF}|g;\
	" blib/script/*

install-perl-modules: check-conflicts perl-modules install-rt-initialdata
	[ -L ${PERL_INC_DEV_KLUDGE}/FS ] \
	  && rm ${PERL_INC_DEV_KLUDGE}/FS \
	  && mv ${PERL_INC_DEV_KLUDGE}/FS.old ${PERL_INC_DEV_KLUDGE}/FS \
	  || true
	cd FS; \
	make install UNINST=1
	#install this for freeside-setup
	install -d $(DIST_CONF)
	#install conf/[a-z]* $(DEFAULT_CONF)
	#CVS is not [a-z]
	install `ls -d conf/[a-z]* | grep -v CVS | grep -v '^conf/registries'` $(DIST_CONF)

dev-perl-modules: perl-modules
	[ -d ${PERL_INC_DEV_KLUDGE}/FS -a ! -L ${PERL_INC_DEV_KLUDGE}/FS ] \
	  && mv ${PERL_INC_DEV_KLUDGE}/FS ${PERL_INC_DEV_KLUDGE}/FS.old \
	  || true

	rm -rf ${PERL_INC_DEV_KLUDGE}/FS
	ln -sf ${FREESIDE_PATH}/FS/blib/lib/FS ${PERL_INC_DEV_KLUDGE}/FS

install-texmf:	
	install -D -o freeside -m 444 etc/fslongtable.sty \
          `kpsewhich -expand-var \\\$$TEXMFLOCAL`/tex/generic/fslongtable.sty
	texhash `kpsewhich -expand-var \\\$$TEXMFLOCAL`

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
	  ( install -o root -m 755 htetc/freeside-base2.conf ${APACHE_CONF} && \
	    ( [ ${RT_ENABLED} -eq 1 ] && install -o root -m 755 htetc/freeside-rt.conf ${APACHE_CONF} || true ) && \
	    ( [ ${TORRUS_ENABLED} -eq 1 ] && install -o root -m 755 htetc/freeside-torrus.conf ${APACHE_CONF} || true ) && \
	    perl -p -i -e "\
	      s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g; \
	      s'%%%FREESIDE_CONF%%%'${FREESIDE_CONF}'g; \
	      s'%%%MASON_HANDLER%%%'${MASON_HANDLER}'g; \
	    " ${APACHE_CONF}/freeside-*.conf \
	  ) || true

install-selfservice:
	[ -e ~freeside ] || cp -pr /etc/skel ~freeside && chown -R freeside ~freeside
	[ -e ~freeside/.ssh/id_dsa.pub ] || [ -e ~freeside/.ssh/id_rsa.pub ] || su - freeside -c 'ssh-keygen -t dsa'
	for MACHINE in ${SELFSERVICE_MACHINES}; do \
	  scp -r fs_selfservice/FS-SelfService ${SELFSERVICE_INSTALL_USER}@$$MACHINE:. ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; perl Makefile.PL && make" ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; sudo make install" ;\
	  scp ~freeside/.ssh/id_dsa.pub ${SELFSERVICE_INSTALL_USER}@$$MACHINE:. ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "sudo ${SELFSERVICE_INSTALL_USERADD} freeside; sudo install -d -o freeside -m 600 ~freeside/.ssh/; sudo install -o freeside -m 600 ./id_dsa.pub ~freeside/.ssh/authorized_keys" ;\
	   ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "sudo install -o freeside -d /usr/local/freeside" ;\
	done

update-selfservice:
	for MACHINE in ${SELFSERVICE_MACHINES}; do \
	  RSYNC_RSH=ssh rsync -rlptz fs_selfservice/FS-SelfService/ ${SELFSERVICE_INSTALL_USER}@$$MACHINE:FS-SelfService ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; make clean; perl Makefile.PL && make" ;\
	  ssh ${SELFSERVICE_INSTALL_USER}@$$MACHINE "cd FS-SelfService; sudo make install" ;\
	done

install-chown:
	chown freeside "${FREESIDE_CACHE}/counters.${DATASOURCE}"
	chown freeside "${FREESIDE_CACHE}/cache.${DATASOURCE}"
	chown freeside "${FREESIDE_EXPORT}/export.${DATASOURCE}"

install: install-perl-modules install-docs install-init install-apache install-rt install-torrus install-texmf install-chown

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

	/bin/echo -e "${DATASOURCE}\n${DB_USER}\n${DB_PASSWORD}" >${FREESIDE_CONF}/secrets
	chmod 600 ${FREESIDE_CONF}/secrets
	chown freeside ${FREESIDE_CONF}/secrets

	mkdir "${FREESIDE_CACHE}/counters.${DATASOURCE}"
	chown freeside "${FREESIDE_CACHE}/counters.${DATASOURCE}"

	mkdir "${FREESIDE_CACHE}/cache.${DATASOURCE}"
	chown freeside "${FREESIDE_CACHE}/cache.${DATASOURCE}"

	mkdir "${FREESIDE_EXPORT}/export.${DATASOURCE}"
	chown freeside "${FREESIDE_EXPORT}/export.${DATASOURCE}"

	#install this for freeside-setup
	install -d $(DIST_CONF)
	#install conf/[a-z]* $(DEFAULT_CONF)
	#CVS is not [a-z]
	install `ls -d conf/[a-z]* | grep -v CVS | grep -v '^conf/registries'` $(DIST_CONF)


configure-rt:
	cd rt; \
	cp config.layout.in config.layout; \
	perl -p -i -e "\
	  s'%%%FREESIDE_DOCUMENT_ROOT%%%'${FREESIDE_DOCUMENT_ROOT}'g;\
	  s'%%%MASONDATA%%%'${MASONDATA}'g;\
	" config.layout; \
	./configure --enable-layout=Freeside\
	            --with-db-type=${DB_TYPE} \
	            --with-db-dba=${DB_USER} \
	            --with-db-database=${RT_DB_DATABASE} \
	            --with-db-rt-user=${DB_USER} \
	            --with-db-rt-pass=${DB_PASSWORD} \
	            --with-web-user=freeside \
	            --with-web-group=freeside \
	            --with-rt-group=freeside \
	            --with-web-handler=modperl2

create-rt: configure-rt
	[ -d /opt           ] || mkdir /opt           #doh
	[ -d /opt/rt3       ] || mkdir /opt/rt3       #
	[ -d /opt/rt3/share ] || mkdir /opt/rt3/share #
	cd rt; make install
	rt/sbin/rt-setup-database --dba '${DB_USER}' \
	                          --dba-password '${DB_PASSWORD}' \
	                          --action schema \
	 || true
	rt/sbin/rt-setup-database --dba-password '${DB_PASSWORD}' \
	                          --action coredata \
	&& rt/sbin/rt-setup-database --dba-password '${DB_PASSWORD}' \
	                             --action insert \
	                             --datafile ${RT_PATH}/etc/initialdata \
	|| true

install-rt: check-conflicts
	if [ ${RT_ENABLED} -eq 1 ]; then ( cd rt; make install ); fi
	if [ ${RT_ENABLED} -eq 1 ]; then perl -p -i -e "\
	  s'%%%RT_DOMAIN%%%'${RT_DOMAIN}'g;\
	  s'%%%RT_TIMEZONE%%%'${RT_TIMEZONE}'g;\
	  s'%%%FREESIDE_URL%%%'${FREESIDE_URL}'g;\
	" ${RT_PATH}/etc/RT_SiteConfig.pm; fi
	if [ ${RT_ENABLED} -eq 1 ]; then \
	  chown -R freeside:freeside ${RT_PATH}/etc; fi

install-rt-initialdata:
	if [ ${RT_ENABLED} -eq 1 ] && [ -d ${RT_PATH} ]; then \
	  chown -R freeside:freeside ${RT_PATH}/etc; \
	  install -D -o freeside -g freeside -m 0440 rt/etc/initialdata \
	  ${RT_PATH}/etc/initialdata; fi

configure-torrus:
	cd torrus; \
	torrus_user=freeside var_user=freeside var_group=freeside ./configure

install-torrus:
	if [ ${TORRUS_ENABLED} -eq 1 ]; then ( cd torrus; \
	  make; \
	  make install; \
	  perl -p -i -e "\
	    s'%%%FREESIDE_URL%%%'${FREESIDE_URL}'g;\
	  " /usr/local/etc/torrus/conf/torrus-siteconfig.pl; \
	  torrus clearcache \
	);fi

clean:
	rm -rf masondocs
	rm -rf httemplate/docs/man
	rm -rf pod2htmi.tmp
	rm -rf pod2htmd.tmp
	-cd FS; \
	make clean
	-cd fs_selfservice/FS-SelfService; \
	make clean

check-conflicts:
	! grep -r --exclude='*config.log*' '--exclude=*config.status*' --exclude=gnupg_details_on_output_formats '--exclude=*mason_handler*' '^=======$$' .

#these are probably only useful if you're me...

#release: upload-docs
.PHONY: release
release:
	# Update the changelog
	#./bin/cvs2cl
	#cvs commit -m "Updated for ${VERSION}" ChangeLog

	# Update the RPM specfile
	#cvs edit ${RPM_SPECFILE}
	#perl -p -i -e "s/\d+[^\}]+/${VERSION}/ if /%define\s+version\s+(\d+[^\}]+)\}/;" ${RPM_SPECFILE}
	#perl -p -i -e "s/\d+[^\}]+/1/ if /%define\s+release\s+(\d+[^\}]+)\}/;" ${RPM_SPECFILE}
	#cvs commit -m "Updated for ${VERSION}" ${RPM_SPECFILE}

	# Update the Debian changelog
	#cvs edit debian/changelog
	#dch -v ${DEBVERSION} -p "New upstream release"
	#cvs commit -m "Updated for ${VERSION}" debian/changelog

	# Make sure other people's changes are pulled in!
	git pull

	# Tag the release
	git tag -f ${TAG}

	#cd /home/ivan
	git archive ${TAG} | gzip -9 >freeside-${VERSION}.tar.gz

	scp freeside-${VERSION}.tar.gz ivan@420.am:/var/www/www.sisd.com/freeside/
	mv freeside-${VERSION} freeside-${VERSION}.tar.gz ..

	#these things failing should not make release target fail, so: "|| true"

	#kick off vmware update
	#./BUILD_VMWARE_APPLIANCE ${$TAG} || true

	#kick off deb package update

	#kick off rpm package update too?

	#update web demo?

	#update web demo self-service?

