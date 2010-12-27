#  Copyright (C) 2002-2010  Stanislav Sinyagin
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

# $Id: configure.ac,v 1.1 2010-12-27 00:03:31 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#


AC_INIT([torrus],[1.0.9],[ssinyagin@users.sourceforge.net])
AC_PREREQ([2.59])
AC_CONFIG_AUX_DIR(conftools)
AC_CANONICAL_HOST
AM_INIT_AUTOMAKE(1.9)

AC_PATH_PROG(PERL, perl, no)

# Need this for init.torrus
AC_PATH_PROG(SU, su, no)
AC_PATH_PROG(KILL, kill, no)
AC_PATH_PROG(SED, sed, no)
AC_PATH_PROG(FIND, find, no)
AC_PATH_PROG(RM, rm, no)
AC_PATH_PROG(SLEEP, sleep, no)


# This will generate doc pages from POD sources
AC_PATH_PROG(POD2TEXT, pod2text, no)
AM_CONDITIONAL([POD2TEXT_PRESENT], [test "$POD2TEXT" != no])
AC_PATH_PROG(POD2MAN, pod2man, no)
AM_CONDITIONAL([POD2MAN_PRESENT], [test "$POD2MAN" != no])

AC_ARG_ENABLE(pkgonly,
        [AC_HELP_STRING([--enable-pkgonly],
                        [Skip all checking])])
AC_SUBST(enable_pkgonly)

AC_ARG_ENABLE(threads,
        [AC_HELP_STRING([--disable-threads],
                        [Disable Perl threads usage])])
        
perllibdirs="\'\${perllibdir}\'"

PERLOPTS=
AC_ARG_VAR(PERLINC,  [[] Additional space-separated Perl library paths])
if test ! -z "$PERLINC"; then
   for d in $PERLINC; do
       PERLOPTS="${PERLOPTS} -I${d}"
       perllibdirs=${perllibdirs}"\,\'"${d}"\'"
   done
fi

find_rrdtool () {
    if ${PERL} -e 'use RRDs' 2>/dev/null; then :; else
        if test "$enable_pkgonly" != yes; then
            AC_MSG_NOTICE([RRDs.pm is not in default Perl search paths.])
            AC_MSG_CHECKING([RRDtool in /usr/local/rrdtool*])
            with_rrdtool=`ls -1dr /usr/local/rrdtool* | head -1`
            if test -d $with_rrdtool; then
               AC_MSG_RESULT([${with_rrdtool}])
            else
               AC_MSG_ERROR([Cannot find RRDtool])
            fi
            test_rrdtool
        else
            with_rrdtool="/usr/local/rrdtool"
        fi
    fi
}

test_rrdtool () {
    if test "$enable_pkgonly" != yes; then
        if ${PERL} -I${with_rrdtool}/lib/perl -e 'use RRDs'; then :; else
            AC_MSG_ERROR([Could not find RRDs perl module in ${with_rrdtool}])
        fi
    fi
    perllibdirs=${perllibdirs}"\,\'"${with_rrdtool}"/lib/perl/\'"
}

AC_ARG_WITH(rrdtool,
        [AC_HELP_STRING(--with-rrdtool=DIR,RRDTool location)],
        test_rrdtool, find_rrdtool)

AC_SUBST(perllibdirs, [${perllibdirs}])


# Check the necessary Perl modules

if test "$enable_pkgonly" != yes; then

   for module in 'BerkeleyDB' 'XML::LibXML' 'Template' \
                 'Proc::Daemon' 'Net::SNMP' 'URI::Escape' 'Apache::Session' \
                 'Date::Parse' 'JSON'
   do
     AC_MSG_CHECKING([presence of $module])
     if ${PERL} ${PERLOPTS} -e 'use '$module 2>/dev/null; then
         AC_MSG_RESULT([Ok])
     else
         AC_MSG_ERROR([Perl cannot find $module]);
     fi
   done

#  Check if Perl threads can be used.
#  Requirements are: perl 5.8.8 with threads compiled,
#  threads ver. 1.41 or higher, threads::shared ver. 1.03 or higher
   
   perlithreads=1
   if test x"$enable_threads" = xno; then
     perlithreads=0     
   else
   
     AC_MSG_CHECKING([if Perl version is 5.8.8 or higher])
     if ${PERL} ${PERLOPTS} -e 'use 5.8.8' 2>/dev/null; then
       AC_MSG_RESULT([Ok])
     else
       perlithreads=0
     fi       

     if test ${perlithreads} -eq 1; then
       AC_MSG_CHECKING([threading support in Perl])
       if ${PERL} ${PERLOPTS} -e 'use threads' 2>/dev/null; then
         AC_MSG_RESULT([Ok])
       else
         perlithreads=0
       fi
     fi

     if test ${perlithreads} -eq 1; then     
       AC_MSG_CHECKING([if threads module version is 1.41 or higher])
       if ${PERL} ${PERLOPTS} -e \
         'use threads; exit($threads::VERSION >= 1.41 ? 0:1)'; then
           AC_MSG_RESULT([Ok])
       else
           perlithreads=0
       fi
     fi

     if test ${perlithreads} -eq 1; then  
       AC_MSG_CHECKING([if threads::shared module version is 1.03 or higher])
       if ${PERL} ${PERLOPTS} -e \
         'use threads; use threads::shared;
          exit($threads::shared::VERSION >= 1.03 ? 0:1)'; then
           AC_MSG_RESULT([Ok])
       else         
           perlithreads=0
       fi
     fi
     
     if test ${perlithreads} -eq 0; then  
       AC_MSG_RESULT([No. Multithreading will not be used.])
     fi
          
   fi
   AC_SUBST(perlithreads, [${perlithreads}])   
fi

AC_ARG_VAR(torrus_user,  [[torrus] UID to run the daemons])
if test -z "$torrus_user"; then
   torrus_user=torrus; fi

if test "$enable_pkgonly" != yes; then
    AC_MSG_CHECKING([if user ${torrus_user} exists])
    torrus_check_file=torrus_usercheck_$$
    torrus_check_error=no
    if ! touch ${torrus_check_file}; then
        AC_MSG_ERROR([Cannot create ${torrus_check_file}])
    elif ! chown ${torrus_user} ${torrus_check_file}; then
        torrus_check_error=yes
    fi
    rm -f ${torrus_check_file}
    if test ${torrus_check_error} = yes; then
        AC_MSG_ERROR([User ${torrus_user} does not exist])
    else
        AC_MSG_RESULT([Ok])
    fi
fi
   

# Set the var/db and var/cache ownership

AC_ARG_VAR(var_user,  [[TORRUS_USER] Owner of db and cache directories])
AC_ARG_VAR(var_group, [[torrus] Group of db and cache directories])
AC_ARG_VAR(var_mode,  [[775] Mode of db and cache directories])

AC_ARG_ENABLE(varperm,
        [AC_HELP_STRING(--disable-varperm,
        Disable db and cache access rights tuning)],
        [],
        [enable_varperm="yes"])
AC_SUBST(enable_varperm)

AC_ARG_VAR(pkghome,   [[PREFIX/torrus] Place for Torrus static files])
if test -z "$pkghome"; then
   pkghome='${prefix}/torrus'; fi

AC_ARG_VAR(pkgbindir,   [[PKGHOME/bin] Torrus executables])
if test -z "$pkgbindir"; then
   pkgbindir='${pkghome}/bin'; fi

AC_ARG_VAR(cfgdefdir,   [[PKGHOME/conf_defaults] torrus-config.pl and others])
if test -z "$cfgdefdir"; then
   cfgdefdir='${pkghome}/conf_defaults'; fi

AC_ARG_VAR(pkgdocdir, [[PKGHOME/doc] Documentation files])
if test -z "$pkgdocdir"; then
   pkgdocdir='${pkghome}/doc'; fi

AC_ARG_VAR(exmpdir, [[PKGHOME/examples] Examples])
if test -z "$exmpdir"; then
   exmpdir='${pkghome}/examples'; fi

AC_ARG_VAR(perllibdir,  [[PKGHOME/perllib] Torrus Perl libraries])
if test -z "$perllibdir"; then
   perllibdir='${pkghome}/perllib'; fi

AC_ARG_VAR(pluginsdir,   [[PKGHOME/plugins] Plugin configurations])
if test -z "$pluginsdir"; then
   pluginsdir='${pkghome}/plugins'; fi

AC_ARG_VAR(plugtorruscfgdir, [[PLUGINSDIR/torrus-config]])
if test -z "$plugtorruscfgdir"; then
   plugtorruscfgdir='${pluginsdir}/torrus-config'; fi

AC_ARG_VAR(plugdevdisccfgdir, [[PLUGINSDIR/devdiscover-config]])
if test -z "$plugdevdisccfgdir"; then
   plugdevdisccfgdir='${pluginsdir}/devdiscover-config'; fi

AC_ARG_VAR(plugwrapperdir, [[PLUGINSDIR/wrapper]])
if test -z "$plugwrapperdir"; then
   plugwrapperdir='${pluginsdir}/wrapper'; fi

      
AC_ARG_VAR(scriptsdir, [[PKGHOME/scripts] Script files])
if test -z "$scriptsdir"; then
   scriptsdir='${pkghome}/scripts'; fi

AC_ARG_VAR(supdir, [[PKGHOME/sup] Supplementary files])
if test -z "$supdir"; then
   supdir='${pkghome}/sup'; fi

AC_ARG_VAR(webplaindir, [[SUPDIR/webplain] Web interface plain files path])
if test -z "$webplaindir"; then
   webplaindir='${supdir}/webplain'; fi

AC_ARG_VAR(webscriptsdir,
        [[SUPDIR/webscripts] Directory for optional web scripts])
if test -z "$webscriptsdir"; then
   webscriptsdir='${supdir}/webscripts'; fi

AC_ARG_VAR(tmpldir, [[PKGHOME/templates] Template files])
if test -z "$tmpldir"; then
   tmpldir='${pkghome}/templates'; fi

AC_ARG_VAR(distxmldir, [[PKGHOME/xmlconfig] Distribution XML config files])
if test -z "$distxmldir"; then
   distxmldir='${pkghome}/xmlconfig'; fi

AC_ARG_VAR(sitedir, [[SYSCONFDIR/torrus] Site configuration files])
if test -z "$sitedir"; then
   sitedir='${sysconfdir}/torrus'; fi

AC_ARG_VAR(siteconfdir, [[SITEDIR/conf] Site configuration files])
if test -z "$siteconfdir"; then
   siteconfdir='${sitedir}/conf'; fi

AC_ARG_VAR(tmpluserdir, [[SITEDIR/templates] User-defined Template files])
if test -z "$tmpluserdir"; then
   tmpluserdir='${sitedir}/templates'; fi

AC_ARG_VAR(sitexmldir, [[SITEDIR/xmlconfig] Site XML configs])
if test -z "$sitexmldir"; then
   sitexmldir='${sitedir}/xmlconfig'; fi

AC_ARG_VAR(logdir, [[/var/log/torrus] Log files])
if test -z "$logdir"; then
   logdir='/var/log/torrus'; fi

AC_ARG_VAR(piddir, [[/var/run/torrus] PID files])
if test -z "$piddir"; then
   piddir='/var/run/torrus'; fi

AC_ARG_VAR(varprefix, [[/var/torrus] Common prefix for runtime data])
if test -z "$varprefix"; then
   varprefix='/var/torrus'; fi
   
AC_ARG_VAR(cachedir, [[VARPREFIX/cache] Renderer cache])
if test -z "$cachedir"; then
   cachedir='${varprefix}/cache'; fi

AC_ARG_VAR(dbhome, [[VARPREFIX/db] Berkeley DB files])
if test -z "$dbhome"; then
   dbhome='${varprefix}/db'; fi

AC_ARG_VAR(reportsdir, [[VARPREFIX/reports] Reports output])
if test -z "$reportsdir"; then
   reportsdir='${varprefix}/reports'; fi

AC_ARG_VAR(seslockdir, [[VARPREFIX/session_data/lock] Web session locks])
if test -z "$seslockdir"; then
   seslockdir='${varprefix}/session_data/lock'; fi

AC_ARG_VAR(sesstordir, [[VARPREFIX/session_data/store] Web session storage])
if test -z "$sesstordir"; then
   sesstordir='${varprefix}/session_data/store'; fi

AC_ARG_VAR(wrapperdir, [[BINDIR] CLI wrapper])
if test -z "$wrapperdir"; then
   wrapperdir='${bindir}'; fi

AC_ARG_VAR(mansec_usercmd, [[1] User commands man section])
if test -z "$mansec_usercmd"; then
   mansec_usercmd='1'; fi

AC_ARG_VAR(mansec_misc, [[7] Miscellaneous man section])
if test -z "$mansec_misc"; then
   mansec_misc='7'; fi

AC_ARG_VAR(defrrddir, [[/srv/torrus/collector_rrd] Default RRD storage path])
if test -z "$defrrddir"; then
   defrrddir='/srv/torrus/collector_rrd'; fi

   
AC_CONFIG_FILES([Makefile bin/Makefile configs/Makefile])
AC_CONFIG_FILES([doc/Makefile doc/manpages/Makefile])
AC_CONFIG_FILES([examples/Makefile perllib/Makefile])
AC_CONFIG_FILES([sup/Makefile xmlconfig/Makefile])
                                    
AC_CONFIG_FILES([setup_tools/substvars.sh],[chmod +x setup_tools/substvars.sh])
AC_CONFIG_FILES([setup_tools/mkvardir.sh], [chmod +x setup_tools/mkvardir.sh])
AC_CONFIG_FILES([init.d/torrus], [chmod +x init.d/torrus])

AC_SUBST(VERSION)

AC_OUTPUT

VARSAVE=configs/instvars
echo creating $VARSAVE
rm -f $VARSAVE
for VAR in $ac_subst_vars; do
    case ${VAR} in
      DEFS | PACKAGE* | INSTALL* | VERSION | ACLOCAL | AUTO* | MAKEINFO |\
      install_sh | AM* | am* | ac* | ECHO* | build* | host* | target* |\
      CYG* | PATH_SEPARATOR | AWK | STRIP | mkdir* |\
      perllibdirs )
      ;;
      *)
        eval 'VAL=${'$VAR'}'
        echo ${VAR}=\'${VAL}\' >>$VARSAVE
      ;;
    esac
done
