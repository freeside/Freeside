%{!?_initrddir:%define _initrddir /etc/rc.d/init.d}
%{!?version:%define version 1.9}
%{!?release:%define release 4}

Summary: Freeside ISP Billing System
Name: freeside
Version: %{version}
Release: %{release}
License: AGPLv3
Group: Applications/Internet
URL: http://www.sisd.com/freeside/
Vendor: Freeside
Source: http://www.sisd.com/freeside/%{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Requires: %{name}-frontend
Requires: %{name}-backend
%if "%{_vendor}" != "suse"
Requires: tetex-latex
%else
Requires: te_latex
%endif
Requires: perl-Fax-Hylafax-Client

%if "%{_vendor}" != "suse"
%define apache_conffile		/etc/httpd/conf/httpd.conf
%define	apache_confdir		/etc/httpd/conf.d
%define	apache_version		2
%define freeside_document_root	/var/www/freeside
%else
%define apache_conffile		/etc/apache2/uid.conf
%define	apache_confdir		/etc/apache2/conf.d
%define	apache_version		2
%define freeside_document_root	/srv/www/freeside
%endif
%define freeside_cache		/var/cache/subsys/freeside
%define freeside_conf		/etc/freeside
%define freeside_export		/etc/freeside
%define freeside_lock		/var/lock/freeside
%define freeside_log		/var/log/freeside
%define freeside_socket		/etc/freeside
%define	rt_enabled		0
%define	fs_queue_user		fs_queue
%define	fs_selfservice_user	fs_selfservice
%define	fs_cron_user		fs_daily
%define	db_types		Pg mysql

%define _rpmlibdir	/usr/lib/rpm

%description
Freeside is a flexible ISP billing system written by Ivan Kohler

%package mason
Summary: HTML::Mason interface for %{name}
Group: Applications/Internet
Prefix: %{freeside_document_root}
%if "%{_vendor}" != "suse"
Requires: mod_ssl
%endif
Requires: perl-Apache-DBI
Conflicts: %{name}-apacheasp
Provides: %{name}-frontend = %{version}
BuildArch: noarch

%description mason
This package includes the HTML::Mason web interface for %{name}.
You should install only one %{name} web interface.

%package postgresql
Summary: PostgreSQL backend for %{name}
Group: Applications/Internet
Requires: perl-DBI
Requires: perl-DBD-Pg >= 1.32
Requires: %{name}
Conflicts: %{name}-mysql
Provides: %{name}-backend = %{version}

%description postgresql
This package includes the PostgreSQL database backend for %{name}.
You should install only one %{name} database backend.
Please note that this RPM does not create the database or database user; it only installs the required drivers.

%package mysql
Summary: MySQL database backend for %{name}
Group: Applications/Internet
Requires: perl-DBI
Requires: perl-DBD-MySQL
Requires: %{name}
Conflicts: %{name}-postgresql
Provides: %{name}-backend = %{version}

%description mysql
This package includes the MySQL database backend for %{name}.
You should install only one %{name} database backend.
Please note that this RPM does not create the database or database user; it only installs the required drivers.

%package selfservice
Summary: Self-service interface for %{name}
Group: Applications/Internet
Conflicts: %{name}
Requires: %{name}-selfservice-cgi

%description selfservice
This package installs the Perl modules and CGI scripts for the self-service interface for %{name}.
For security reasons, it is set to conflict with %{name} as you should not install the billing system and self-service interface on the same computer.

%package selfservice-core
Summary: Core Perl libraries for the self-service interface for %{name}
Group: Applications/Internet
Conflicts: %{name}

%description selfservice-core
This package installs the Perl modules and client daemon for the self-service interface for %{name}.  It does not install the CGI interface and can be used with a different front-end.
For security reasons, it is set to conflict with %{name} as you should not install the billing system and self-service interface on the same computer.

%package selfservice-cgi
Summary: CGI scripts for the self-service interface for %{name}
Group: Applications/Internet
Conflicts: %{name}
Requires: %{name}-selfservice-core
Prefix: %{freeside_document_root}/selfservice

%description selfservice-cgi
This package installs the CGI scripts for the self-service interface for %{name}.  The scripts use some core libraries packaged in a separate RPM.
For security reasons, it is set to conflict with %{name} as you should not install the billing system and self-service interface on the same computer.

%package selfservice-php
Summary: Sample PHP files for the self-service interface for %{name}
Group: Applications/Internet
Conflicts: %{name}
Prefix: %{freeside_document_root}/selfservice

%description selfservice-php
This package installs the sample PHP scripts for the self-service interface for %{name}.
For security reasons, it is set to conflict with %{name} as you should not install the billing system and self-service interface on the same computer.

%prep
%setup -q
%{__rm} bin/pod2x # Only useful to Ivan Kohler now
perl -pi -e 's|/usr/local/bin|%{_bindir}|g' FS/Makefile.PL
perl -pi -e 's|\s+-o\s+freeside\s+| |g' Makefile
perl -ni -e 'print if !/\s+chown\s+/;' Makefile

# Fix-ups for self-service.  Should merge this into Makefile
perl -pi -e 's|/usr/local/sbin|%{_sbindir}|g' FS/bin/freeside-selfservice-server
perl -pi -e 's|/usr/local/bin|%{_bindir}|g' fs_selfservice/FS-SelfService/Makefile.PL
perl -pi -e 's|/usr/local/freeside|%{freeside_socket}|g' fs_selfservice/FS-SelfService/*.pm
perl -pi -e 's|socket\s*=\s*"/usr/local/freeside|socket = "%{freeside_socket}|g' fs_selfservice/FS-SelfService/freeside-selfservice-*
perl -pi -e 's|log_file\s*=\s*"/usr/local/freeside|log_file = "%{freeside_log}|g' fs_selfservice/FS-SelfService/freeside-selfservice-*
perl -pi -e 's|lock_file\s*=\s*"/usr/local/freeside|lock_file = "%{freeside_lock}|g' fs_selfservice/FS-SelfService/freeside-selfservice-*

# Fix-ups for SuSE
%if "%{_vendor}" == "suse"
perl -pi -e 's|htpasswd|/usr/sbin/htpasswd2|g if /system/;' FS/FS/access_user.pm
perl -pi -e 'print "Order deny,allow\nAllow from all\n" if /<Files/i;' htetc/freeside*.conf
%endif

# Override find-requires/find-provides to supplement Perl requires for HTML::Mason file handler.pl
cat << \EOF > %{name}-req
#!/bin/sh
tee %{_tmppath}/filelist | %{_rpmlibdir}/rpmdeps --requires | grep -v -E '^perl\(the\)$' \
| grep -v -E '^perl\((lib|strict|vars|RT)\)$' \
| grep -v -E '^perl\(RT::' \
| sort -u
grep handler.pl %{_tmppath}/filelist | xargs %{_rpmlibdir}/perldeps.pl --requires \
| grep -v -E '^perl\((lib|strict|vars|RT)\)$' \
| grep -v -E '^perl\(RT::' \
| sort -u
EOF

%define __find_provides %{_rpmlibdir}/rpmdeps --provides
%define __find_requires %{_builddir}/%{name}-%{version}/%{name}-req
%{__chmod} +x %{__find_requires}
%define _use_internal_dependency_generator 0

%build

# False laziness...
# The htmlman target now makes wiki documentation.  Let's pretend we made it.
touch htmlman
%{__make} alldocs

#perl -pi -e 's|%%%%%%VERSION%%%%%%|%{version}|g' FS/bin/*
cd FS
if [ "%{_vendor}" = "suse" ]; then
	CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL
else
	CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL PREFIX=$RPM_BUILD_ROOT%{_prefix} SITELIBEXP=$RPM_BUILD_ROOT%{perl_sitelib} SITEARCHEXP=$RPM_BUILD_ROOT%{perl_sitearch} INSTALLSCRIPT=$RPM_BUILD_ROOT%{_bindir}
fi
%{__make} OPTIMIZE="$RPM_OPT_FLAGS"
cd ..
%{__make} perl-modules VERSION='%{version}-%{release}' RT_ENABLED=%{rt_enabled} FREESIDE_CACHE=%{freeside_cache} FREESIDE_CONF=%{freeside_conf} FREESIDE_EXPORT=%{freeside_export} FREESIDE_LOCK=%{freeside_lock} FREESIDE_LOG=%{freeside_log}
touch perl-modules

cd fs_selfservice/FS-SelfService
if [ "%{_vendor}" = "suse" ]; then
	CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL
else
	CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL PREFIX=$RPM_BUILD_ROOT%{_prefix} SITELIBEXP=$RPM_BUILD_ROOT%{perl_sitelib} SITEARCHEXP=$RPM_BUILD_ROOT%{perl_sitearch} INSTALLSCRIPT=$RPM_BUILD_ROOT%{_sbindir}
fi
%{__make} OPTIMIZE="$RPM_OPT_FLAGS"
cd ../..

%install
%{__rm} -rf %{buildroot}

%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}

touch install-perl-modules perl-modules
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_cache}
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_conf}
#%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_export}
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_lock}
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_log}
for DBTYPE in %{db_types}; do
	%{__mkdir_p} $RPM_BUILD_ROOT/tmp
	[ -d $RPM_BUILD_ROOT%{freeside_conf}/default_conf ] && %{__rm} -rf $RPM_BUILD_ROOT%{freeside_conf}/default_conf
	%{__make} create-config DB_TYPE=$DBTYPE DATASOURCE=DBI:$DBTYPE:dbname=%{name} RT_ENABLED=%{rt_enabled} FREESIDE_CACHE=$RPM_BUILD_ROOT%{freeside_cache} FREESIDE_CONF=$RPM_BUILD_ROOT/tmp FREESIDE_EXPORT=$RPM_BUILD_ROOT%{freeside_export} FREESIDE_LOCK=$RPM_BUILD_ROOT%{freeside_lock} FREESIDE_LOG=$RPM_BUILD_ROOT%{freeside_log}
	%{__mv} $RPM_BUILD_ROOT/tmp/* $RPM_BUILD_ROOT%{freeside_conf}
	/bin/rmdir $RPM_BUILD_ROOT/tmp
done
%{__rm} install-perl-modules perl-modules $RPM_BUILD_ROOT%{freeside_conf}/conf*/ticket_system

touch docs
%{__perl} -pi -e "s|%%%%%%FREESIDE_DOCUMENT_ROOT%%%%%%|%{freeside_document_root}|g" htetc/handler.pl
%{__make} install-docs RT_ENABLED=%{rt_enabled} PREFIX=$RPM_BUILD_ROOT%{_prefix} TEMPLATE=mason FREESIDE_DOCUMENT_ROOT=$RPM_BUILD_ROOT%{freeside_document_root} MASON_HANDLER=$RPM_BUILD_ROOT%{freeside_conf}/handler.pl MASONDATA=$RPM_BUILD_ROOT%{freeside_cache}/masondata
%{__perl} -pi -e "s|$RPM_BUILD_ROOT||g" $RPM_BUILD_ROOT%{freeside_conf}/handler.pl
%{__rm} docs

# Install the init script
%{__mkdir_p} $RPM_BUILD_ROOT%{_initrddir}
%{__install} init.d/freeside-init $RPM_BUILD_ROOT%{_initrddir}/%{name}
#%{__make} install-init INSTALLGROUP=root INIT_FILE=$RPM_BUILD_ROOT%{_initrddir}/%{name}
%{__perl} -pi -e "\
	  s/%%%%%%QUEUED_USER%%%%%%/%{fs_queue_user}/g;\
	  s/%%%%%%SELFSERVICE_USER%%%%%%/%{fs_selfservice_user}/g;\
	  s/%%%%%%SELFSERVICE_MACHINES%%%%%%//g;\
	  s|/etc/default|/etc/sysconfig|g;\
	" $RPM_BUILD_ROOT%{_initrddir}/%{name}

# Install the HTTPD configuration snippet for HTML::Mason
%{__mkdir_p} $RPM_BUILD_ROOT%{apache_confdir}
%{__make} install-apache FREESIDE_DOCUMENT_ROOT=%{freeside_document_root} RT_ENABLED=%{rt_enabled} APACHE_CONF=$RPM_BUILD_ROOT%{apache_confdir} APACHE_VERSION=%{apache_version} FREESIDE_CONF=%{freeside_conf} MASON_HANDLER=%{freeside_conf}/handler.pl
%{__perl} -pi -e "s|%%%%%%FREESIDE_DOCUMENT_ROOT%%%%%%|%{freeside_document_root}|g" $RPM_BUILD_ROOT%{apache_confdir}/freeside-*.conf
%{__perl} -pi -e "s|%%%%%%MASON_HANDLER%%%%%%|%{freeside_conf}/handler.pl|g" $RPM_BUILD_ROOT%{apache_confdir}/freeside-*.conf
%{__perl} -pi -e "s|/usr/local/etc/freeside|%{freeside_conf}|g" $RPM_BUILD_ROOT%{apache_confdir}/freeside-*.conf
%{__perl} -pi -e 'print "Alias /%{name} %{freeside_document_root}\n\n" if /^<Directory/;' $RPM_BUILD_ROOT%{apache_confdir}/freeside-*.conf
%{__perl} -pi -e 'print "SSLRequireSSL\n" if /^AuthName/i;' $RPM_BUILD_ROOT%{apache_confdir}/freeside-*.conf

# Make lists of the database-specific configuration files
for DBTYPE in %{db_types}; do
	echo "%%attr(600,freeside,freeside) %{freeside_conf}/secrets" > %{name}-%{version}-%{release}-$DBTYPE-filelist
	for DIR in `echo -e "%{freeside_conf}\n%{freeside_cache}\n%{freeside_export}\n" | sort | uniq`; do
		find $RPM_BUILD_ROOT$DIR -type f -print | \
			grep ":$DBTYPE:" | \
			sed "s@^$RPM_BUILD_ROOT@%%attr(640,freeside,freeside) %%config(noreplace) @g" >> %{name}-%{version}-%{release}-$DBTYPE-filelist
		find $RPM_BUILD_ROOT$DIR -type d -print | \
			grep ":$DBTYPE:" | \
			sed "s@^$RPM_BUILD_ROOT@%%attr(711,freeside,freeside) %%dir @g" >> %{name}-%{version}-%{release}-$DBTYPE-filelist
	done
	if [ "$(cat %{name}-%{version}-%{release}-$DBTYPE-filelist)X" = "X" ] ; then
		echo "ERROR: EMPTY FILE LIST"
		exit 1
	fi
done

# Make a list of the Mason files before adding self-service, etc.
echo "%attr(-,freeside,freeside) %{freeside_conf}/handler.pl" > %{name}-%{version}-%{release}-mason-filelist
find $RPM_BUILD_ROOT%{freeside_document_root} -type f -print | \
	sed "s@^$RPM_BUILD_ROOT@@g" >> %{name}-%{version}-%{release}-mason-filelist
if [ "$(cat %{name}-%{version}-%{release}-mason-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit 1
fi

# Install all the miscellaneous binaries into /usr/share or similar
%{__mkdir_p} $RPM_BUILD_ROOT%{_datadir}/%{name}-%{version}/bin
%{__install} bin/* $RPM_BUILD_ROOT%{_datadir}/%{name}-%{version}/bin

%{__mkdir_p} $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig
%{__install} rpm/freeside.sysconfig $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/%{name}

%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi/images
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi/misc
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/php
%{__mkdir_p} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/templates
%{__install} fs_selfservice/FS-SelfService/cgi/{*.cgi,*.html,*.gif} $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi
%{__install} fs_selfservice/FS-SelfService/cgi/images/* $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi/images
%{__install} fs_selfservice/FS-SelfService/cgi/misc/* $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/cgi/misc
%{__install} fs_selfservice/php/* $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/php
%{__install} fs_selfservice/FS-SelfService/*.template $RPM_BUILD_ROOT%{freeside_document_root}/selfservice/templates

# Install the main billing server Perl files
cd FS
eval `perl '-V:installarchlib'`
%{__mkdir_p} $RPM_BUILD_ROOT$installarchlib
%makeinstall PREFIX=$RPM_BUILD_ROOT%{_prefix}
%{__rm} -f `find $RPM_BUILD_ROOT -type f -name perllocal.pod -o -name .packlist`

[ -x %{_rpmlibdir}/brp-compress ] && %{_rpmlibdir}/brp-compress

find $RPM_BUILD_ROOT%{_prefix} -type f -print | \
	grep -v '/etc/freeside/conf' | \
	grep -v '/etc/freeside/secrets' | \
	sed "s@^$RPM_BUILD_ROOT@@g" > %{name}-%{version}-%{release}-filelist
if [ "$(cat %{name}-%{version}-%{release}-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit 1
fi
cd ..

# Install the self-service interface Perl files
cd fs_selfservice/FS-SelfService
%{__mkdir_p} $RPM_BUILD_ROOT%{_prefix}/local/bin
%makeinstall PREFIX=$RPM_BUILD_ROOT%{_prefix}
%{__rm} -f `find $RPM_BUILD_ROOT -type f -name perllocal.pod -o -name .packlist`

[ -x %{_rpmlibdir}/brp-compress ] && %{_rpmlibdir}/brp-compress

find $RPM_BUILD_ROOT%{_prefix} -type f -print | \
	grep -v '/etc/freeside/conf' | \
	grep -v '/etc/freeside/secrets' | \
	sed "s@^$RPM_BUILD_ROOT@@g" > %{name}-%{version}-%{release}-temp-filelist
cat ../../FS/%{name}-%{version}-%{release}-filelist %{name}-%{version}-%{release}-temp-filelist | sort | uniq -u > %{name}-%{version}-%{release}-selfservice-core-filelist
if [ "$(cat %{name}-%{version}-%{release}-selfservice-core-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit 1
fi
cd ../..

%pre
if ! %{__id} freeside &>/dev/null; then
	/usr/sbin/useradd freeside
fi

%pre mason
if ! %{__id} freeside &>/dev/null; then
	/usr/sbin/useradd freeside
fi

%pre postgresql
if ! %{__id} freeside &>/dev/null; then
	/usr/sbin/useradd freeside
fi

%pre mysql
if ! %{__id} freeside &>/dev/null; then
	/usr/sbin/useradd freeside
fi

%pre selfservice-cgi
if ! %{__id} freeside &>/dev/null; then
	/usr/sbin/useradd freeside
fi

%post
if [ -x /sbin/chkconfig ]; then
	/sbin/chkconfig --add freeside
fi
#if [ $1 -eq 2 -a -x /usr/bin/freeside-upgrade ]; then
#	/usr/bin/freeside-upgrade
#fi

%post postgresql
if [ -f %{freeside_conf}/secrets ]; then
	perl -p -i.fsbackup -e 's/^DBI:.*?:/DBI:Pg:/' %{freeside_conf}/secrets
fi

%post mysql
if [ -f %{freeside_conf}/secrets ]; then
	perl -p -i.fsbackup -e 's/^DBI:.*?:/DBI:mysql:/' %{freeside_conf}/secrets
fi

%post mason
# Make local httpd run with User/Group = freeside
if [ -f %{apache_conffile} ]; then
	perl -p -i.fsbackup -e 's/^(User|Group) .*/$1 freeside/' %{apache_conffile}
fi

%clean
%{__rm} -rf %{buildroot}

%files -f FS/%{name}-%{version}-%{release}-filelist
%attr(0711,root,root) %{_initrddir}/%{name}
%attr(0644,root,root) %config(noreplace) %{_sysconfdir}/sysconfig/%{name}
%defattr(-,freeside,freeside,-)
%doc README INSTALL CREDITS AGPL
%attr(-,freeside,freeside) %dir %{freeside_conf}
%attr(-,freeside,freeside) %dir %{freeside_lock}
%attr(-,freeside,freeside) %dir %{freeside_log}
%attr(0644,freeside,freeside) %config(noreplace) %{freeside_conf}/default_conf

%files mason -f %{name}-%{version}-%{release}-mason-filelist
%defattr(-, freeside, freeside, 0755)
%attr(-,freeside,freeside) %{freeside_cache}/masondata
%attr(0644,root,root) %config(noreplace) %{apache_confdir}/%{name}-base%{apache_version}.conf

%files postgresql -f %{name}-%{version}-%{release}-Pg-filelist

%files mysql -f %{name}-%{version}-%{release}-mysql-filelist

%files selfservice
%defattr(-, freeside, freeside, 0644)

%files selfservice-core -f fs_selfservice/FS-SelfService/%{name}-%{version}-%{release}-selfservice-core-filelist
%defattr(-, freeside, freeside, 0644)
%attr(-,freeside,freeside) %dir %{freeside_socket}
%attr(-,freeside,freeside) %dir %{freeside_lock}
%attr(-,freeside,freeside) %dir %{freeside_log}

%files selfservice-cgi
%defattr(-, freeside, freeside, 0644)
%attr(0711,freeside,freeside) %{freeside_document_root}/selfservice/cgi
%attr(0644,freeside,freeside) %{freeside_document_root}/selfservice/templates

%files selfservice-php
%defattr(-, freeside, freeside, 0644)
%attr(0755,freeside,freeside) %{freeside_document_root}/selfservice/php

%changelog
* Tue Dec 9 2008 Richard Siddall <richard.siddall@elirion.net> - 1.9-4
- Cleaning up after rpmlint

* Tue Aug 26 2008 Richard Siddall <richard.siddall@elirion.net> - 1.9-3
- More revisions for self-service interface

* Sat Aug 23 2008 Richard Siddall <richard.siddall@elirion.net> - 1.7.3-2
- Revisions for self-service interface
- RT support is still missing

* Sun Jul 8 2007 Richard Siddall <richard.siddall@elirion.net> - 1.7.3
- Updated for upcoming Freeside 1.7.3
- RT support is still missing

* Fri Jun 29 2007 Richard Siddall <richard.siddall@elirion.net> - 1.7.2
- Updated for Freeside 1.7.2
- Removed support for Apache::ASP

* Wed Oct 12 2005 Richard Siddall <richard.siddall@elirion.net> - 1.5.7
- Added self-service package

* Sun Feb 06 2005 Richard Siddall <richard.siddall@elirion.net> - 1.5.0pre6-1
- Initial package
