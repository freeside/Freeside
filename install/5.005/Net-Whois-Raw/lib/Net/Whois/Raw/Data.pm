package Net::Whois::Raw::Data;

use strict;
use vars qw(%notfound %strip);

our %servers = qw(
    COM    whois.crsnic.net
    NET    whois.crsnic.net
    EDU    whois.educause.net
    ORG    whois.publicinterestregistry.net
    ARPA   whois.arin.net
    RIPE   whois.ripe.net
    MIL    whois.nic.mil
    COOP   whois.nic.coop
    MUSEUM whois.museum

    BIZ    whois.neulevel.biz
    INFO   whois.afilias.net
    NAME   whois.nic.name
    GOV    whois.nic.gov
    AERO   whois.information.aero
    NS     whois.internic.net
    IP     whois.ripe.net

    AD  whois.ripe.net
    AL  whois.ripe.net
    AM  whois.ripe.net
    AS  whois.gdns.net
    AT  whois.nic.at
    AU  box2.aunic.net
    AZ  whois.ripe.net
    BA  whois.ripe.net
    BE  whois.dns.be
    BG  whois.ripe.net
    BR  whois.nic.br
    BY  whois.ripe.net
    CA  eider.cira.ca
    CC  whois.nic.cc
    CH  domex.switch.ch
    CK  whois.ck-nic.org.ck
    CL  nic.cl
    CN  log.cnnic.net.cn
    CX  whois.nic.cx
    CY  whois.ripe.net
    CZ  dc1.eunet.cz
    DE  whois.denic.de
    DK  whois.dk-hostmaster.dk
    DO  ns.nic.do
    DZ  whois.ripe.net
    EE  whois.ripe.net
    EG  whois.ripe.net
    ES  whois.ripe.net
    FI  whois.ripe.net
    FO  whois.ripe.net
    FR  winter.nic.fr
    GA  whois.ripe.net
    GB  whois.ripe.net
    GE  whois.ripe.net
    GL  whois.ripe.net
    GM  whois.ripe.net
    GR  whois.ripe.net
    GS  whois.adamsnames.tc
    HK  whois.hkdnr.net.hk
    HR  whois.ripe.net
    HU  whois.nic.hu
    ID  muara.idnic.net.id
    IE  whois.domainregistry.ie
    IL  whois.isoc.org.il
    IN  whois.ncst.ernet.in
    IS  horus.isnic.is
    IT  whois.nic.it
    JO  whois.ripe.net
    JP  whois.nic.ad.jp
    KG  whois.domain.kg
    KH  whois.nic.net.kh
    KR  whois.krnic.net
    LA  whois.nic.la
    LI  domex.switch.ch
    LK  arisen.nic.lk
    LT  ns.litnet.lt
    LU  whois.dns.lu
    LV  whois.ripe.net
    MA  whois.ripe.net
    MC  whois.ripe.net
    MD  whois.ripe.net
    MM  whois.nic.mm
    MS  whois.adamsnames.tc
    MT  whois.ripe.net
    MX  whois.nic.mx
    NL  gw.domain-registry.nl
    NO  ask.norid.no
    NU  whois.worldnames.net
    NZ  akl-iis.domainz.net.nz
    PL  nazgul.nask.waw.pl
    PT  whois.ripe.net
    RO  whois.rotld.ro
    RU  whois.ripn.net
    SE  ear.nic-se.se
    SG  qs.nic.net.sg
    SH  whois.nic.sh
    SI  whois.arnes.si
    SK  whois.ripe.net
    SM  whois.ripe.net
    ST  whois.nic.st
    SU  whois.ripn.net
    TC  whois.adamsnames.tc
    TF  whois.adamsnames.tc
    TH  whois.thnic.net
    TJ  whois.nic.tj
    TN  whois.ripe.net
    TO  whois.tonic.to
    TR  whois.ripe.net
    TW  whois.twnic.net
    UA  whois.net.ua
    UK  whois.nic.uk
    US  whois.nic.us
    VA  whois.ripe.net
    VG  whois.adamsnames.tc
    WS  whois.worldsite.ws
    YU  whois.ripe.net
    ZA  apies.frd.ac.za

    RA--AQ5D4PA	whois.i-dns.net
    RA--AQ6TKQQ	whois.i-dns.net
    RA--AQ7EAMY	whois.i-dns.net
    XN--P1AG	ru.whois.i-dns.net
    XN--P1AG	ru.whois.i-dns.net
    XN--J1AEF	whois.i-dns.net
    XN--E1APQ	whois.i-dns.net
    XN--C1AVG	whois.i-dns.net

    NET.RU	whois.ripn.net
    ORG.RU	whois.ripn.net
    PP.RU	whois.ripn.net
    SPB.RU	whois.relcom.ru
    MSK.RU	whois.relcom.ru
    RU.NET	whois.relcom.ru
);

# These do not seem to work
#         CN  log.cnnic.net.cn
#         DK  whois.dk-hostmaster.dk
#         US  whois.isi.edu
# These serve only several subdomains
#         ZA  apies.frd.ac.za


%notfound = (
    'whois.nic.cc' => '^No match for',
    'whois.arin.net' => '^No match for',
    'whois.nic.br' => 'No match for',
    'ear.nic-se.se' => 'No data found',
    'whois.nic.sh' => '^No match for',
    'whois.nic.mx' => '^Nombre del Dominio:',
    'whois.domainregistry.ie' => 'There was no match',
    'domex.switch.ch' => '^We do not have an entry in our database matching your',
    'whois.dns.lu' => 'No entries found',
    'whois.worldsite.ws' => 'No match for',
    'whois.nic.it' => '^No entries found',
    'whois.nic.coop' => 'No Objects Found',
    'whois.nic.at' => 'nothing found',
    'ask.norid.no' => 'no matches',
    'whois.nic.uk' => '^\\s*No match for',
    'whois.nic.ad.jp' => 'No match',
    'whois.arnes.si' => 'No entries found',
    'whois.tonic.to' => 'No match for',
    'whois.hkdnr.net.hk' => '^No Match for',
    'whois.worldnames.net' => 'NO MATCH for domain',
    'whois.rotld.ro' => 'No entries found',
    'whois.nic.st' => '^No entries found',
    'whois.isoc.org.il' => 'No data was found',
    'eider.cira.ca' => 'Status:\\s*UNAV',
    'whois.nic.tj' => '^No match for',
    'aardvark.dns.be' => 'No such domain',
    'nazgul.nask.waw.pl' => '^Domain name .* does not exists',
    'whois.ncst.ernet.in' => '^No matches',
    'whois.krnic.net' => 'Above domain name is not registered',
    'whois.museum' => '^No information for',
    'whois.net.ua' => 'No entries found',
    'apies.frd.ac.za' => 'No information is available',
    'gw.domain-registry.nl' => 'invalid query',
    'whois.denic.de' => 'No entries found',
    'whois.nic.mil' => '^No match for',
    'horus.isnic.is' => 'No entries found',
    'winter.nic.fr' => 'No entries found',
    'whois.ripe.net' => 'No entries found',
    'whois.ripn.net' => 'No entries found',
    'qs.nic.net.sg' => 'NO entry found',
    'whois.twnic.net' => '^NO MATCH: This domain is',
    'nic.cl' => 'Invalid domain name',
    'whois.gdns.net' => '^Domain Not Found',
    'box2.aunic.net' => 'No entries found',
    'whois.nic.cx' => '^No match for',
    'dc1.eunet.cz' => 'No data found',
    'akl-iis.domainz.net.nz' => 'domain_name_status: 00 Not Listed',
    'ns.litnet.lt' => 'No matches found',
    'whois.adamsnames.tc' => 'is not a domain controlled by',
    'whois.nic.la' => '^NO MATCH for',
    'whois.networksolutions.com' => '(?i)no match',
    'whois.thnic.net' => 'No entries found',
    'whois.neulevel.biz' => '^Not found:',
    'whois.afilias.net' => '^NOT FOUND',
);

%strip = (
    'whois.crsnic.net' => [
	'^TERMS OF USE:',
	'^database through',
	'^automated except',
	'^modify existing',
	'^Services\' \(\"VeriSign\"\)',
	'^information purposes only',
	'^about or related to a',
	'^guarantee its accuracy\.',
	'^by the following terms',
	'^for lawful purposes and',
	'^to: (1) allow, enable,',
	'^unsolicited, commercial',
	'^or facsimile; or \(2\)',
	'^that apply to VeriSign',
	'^repackaging, dissemination',
	'^prohibited without the',
	'^use electronic processes',
	'^query the Whois database',
	'^domain names or modify',
	'^to restrict your access',
	'^operational stability\.',
	'^Whois database for',
	'^reserves the right',

	'^NOTICE AND TERMS OF USE:',
	'^Data in Network Solutions',
	'^purposes only, and to assist',
	'^to a domain name registration',
	'^By submitting a WHOIS query,',
	'^You agree that you may use',
	'^circumstances will you use',
	'^the transmission of mass',
	'^via e-mail, telephone, or',
	'^electronic processes that',
	'^compilation, repackaging,',
	'^high-volume, automated,',
	'^database. Network Solutions',
	'^database in its sole discretion,',
	'^querying of the WHOIS database',
	'^Network Solutions reserves the',

	'^NOTICE: The expiration date',
	'^registrar\'s sponsorship of',
	'^currently set to expire\.',
	'^date of the domain name',
	'^registrar.  Users may',
	'^view the registrar\'s',
	'^to: \(1\) allow, enable,',
	'^The Registry database',
	'^Registrars\.',
	'^Domain not found locally,',
	'^Local WHOIS DB must be out',

	'^Whois Server Version',
	'^Domain names in the .com',
	'^with many different',
	'^for detailed information\.',

	'^>>> Last update of whois database',
	'^$',
    ],
    'whois.tonic.to' => [
	'^Tonic whoisd',
    ],
    'whois.net.ua' => [
	'^%',
    ],
    'whois.nic.cx' => [
	'^ Registrar: Christmas Island',
	'^ Whois Server: whois.nic.cx',
    ],
    'gw.domain-registry.nl' => [
	'Rights restricted by copyright',
	'http://www.domain-registry.nl',
    ],
    'whois.denic.de' => [
	'^%',
    ],
    'whois.gdns.net' => [
	'^\\w+ Whois Server',
	'^Access to .* WHOIS information is provided to',
	'^determining the contents of a domain name',
	'^registrar database.  The data in',
	'^informational purposes only, and',
	'^Compilation, repackaging, dissemination,',
	'^in its entirety, or a substantial portion',
	'prior written permission.  By',
	'^by this policy.  All rights reserved.',
    ],
    'whois.isoc.org.il' => [
	'^%',
    ],
    'whois.dns.lu' => [
	'^%',
    ],
    'whois.worldnames.net' => [
	'^----------------------------------',
	'^.\\w+ Domain .* Whois service',
	'^Copyright by .* Domain LTD',
	'^----------------------------------',
	'^Database last updated',
    ],
    'whois.nic.sh' => [
	'^NIC Whois Server',
    ],
    'whois.nic.coop' => [
	'^%',
	'^ The .COOP Registration',
	'^ Please use the',
    ],
    'domex.switch.ch' => [
	'^whois: This information is subject',
	'^See http',
    ],
    'whois.twnic.net' => [
	'^Registrar:',
	'^URL: http://rs.twnic.net.tw',
    ],
    'nic.cl' => [
	'^cl.cl:',
	'^Más información: http://www.nic.cl/',
    ],
    'whois.nic.mx' => [
	'^------------------',
	'^La información que ha',
	'^relacionados con la',
	'^DNS administrado por el NIC-México.',
	'^Queda absolutamente prohibido',
	'^envío de e-mail no solicitado',
	'^productos y servicios',
	'^del NIC-México.',
	'^La base de datos generada',
	'^protegida por las leyes de',
	'^internacionales sobre la materia.',
    ],
    'whois.domainregistry.ie' => [
	'^%',
    ],
    'ns.litnet.lt' => [
	'^%',
    ],
    'dc1.eunet.cz' => [
	'^%',
    ],
    'whois.ripn.net' => [
	'^%',
    ],
    'whois.nic.uk' => [
	'^The .* Registration Host contains information',
	'^registrations in the .*co.uk',
	'and .*\\.uk second-level domains.',
    ],
    'whois.nic.br' => [
	'^%',
    ],
    'whois.krnic.net' => [
	'^Korea Internet Information Service',
	'^20\\d\\d³â 7¿ù 2ÀÏºÎÅÍ´Â °³¼±µÈ Whois',
	'^.com, .net, .org',
    ],
    'whois.arnes.si' => [
	'^\\*',
    ],
    'nazgul.nask.waw.pl' => [
	'^%',
    ],
    'whois.nic.la' => [
	'^   WHOIS server',
	'^   The Data in the',
	'for information purposes,',
	'^   and to assist persons in obtaining',
	'^   domain name registration record. Sterling Holdings, Limited,',
	'^   does not guarantee its accuracy.',
	'^   you will use this Data only for lawful',
	'^   circumstances will you use this Data',
	'^   \\(1\\) allow, enable, or otherwise s',
	'^   unsolicited, commercial advertising',
	'^   \\(spam\\); or',
	'^   that apply to Sterling Holdings',
	'^   Sterling Holdings .* reserves the right to modify',
	'^   terms at any time. By submitting this',
	'^   policy.',
    ],
    'horus.isnic.is' => [
	'^%',
    ],
    'whois.rotld.ro' => [
	'^%',
    ],
    'whois.nic.st' => [
	'^The data in the .* database is provided',
	'^The .* Registry does not guarantee',
	'^The data in the .* database is protected',
	'^By submitting a .* query, you agree that you will',
	'^The Domain Council of .* reserves the right',
    ],
    'ask.norid.no' => [
	'^%',
    ],
    'whois.hkdnr.net.hk' => [
	'^Whois server',
	'^Domain names in the',
	'^and .* can now be registered',
	'^Go to http://www.hkdnr.net.hk',
	'^---------',
	'^The Registry contains ONLY',
	'^.* and .*\\.HK domains.',
    ],
    'whois.arin.net' => [
	'^The ARIN Registration Services Host contains',
	'^Network Information:.*Networks',
	'^Please use the whois server at',
	'^Information and .* for .* Information.',
    ],
    'qs.nic.net.sg' => [
	'^\\*',
    ],
    'akl-iis.domainz.net.nz' => [
	'^%',
    ],
    'whois.nic.hu' => [
	'^%',
    ],
    'whois.worldsite.ws' => [
	'^Welcome to the .* Whois Server',
	'^Use of this service for any',
	'^than determining the',
	'^in the .* to be registered',
	'^prohibited.',
    ],
    'whois.ripe.net' => [
	'^%',
    ],
    'whois.nic.cc' => [
	'^This information is',
	'^The Data in eNIC',
	'^Corporation for information',
	'^in obtaining information',
	'^registration record',
	'^accuracy.  By submitting',
	'^will use this Data only',
	'^no circumstances will',
	'^or otherwise support',
	'^commercial advertising',
	'^or \\(2\\) enable high volume',
	'^apply to eNIC Corporation',
	'^reserves the right to',
	'^submitting this query,',
    ],
    'whois.nic.mil' => [
	'^To single out one record',
	'^handle, shown in parenthesis',
	'^Please be advised that this whois',
	'^All INTERNET Domain, IP Network Number,',
	'^the Internet Registry, RS.INTERNIC.NET.',
    ],
    'box2.aunic.net' => [
	'^%',
    ],
    'whois.nic.ad.jp' => [
	'^[',
    ],
    'winter.nic.fr' => [
	'^Tous droits reserves par copyright.',
	'^Voir http://www.nic.fr',
	'^Rights restricted by copyright.',
	'^See http://www.nic.fr/outils',
    ],
    'ear.nic-se.se' => [
	'^#',
    ],
    'whois.networksolutions.com' => [
	'^The Data in',
	'^Solutions for information',
	'^information about or',
	'^Network Solutions does not guarantee',
	'^WHOIS query, you agree that',
	'^purposes and that, under no circumstances',
	'^\\(1\\) allow, enable, or',
	'^unsolicited, commercial advertising',
	'^\\(spam\\); or',
	'^that apply to Network',
	'^reserves the right',
	'^this query, you',
    ],
    'aardvark.dns.be' => [
	'^%',
    ],
    'whois.dns.be' => [
	'^%-',
    ],
    'whois.nic.tj' => [
	'^This Whois server looks up only',
	'^Please see http://nic.tj for more',
	'^Tajikistan, and the Public Registrar Network.',
    ],
    'whois.nic.at' => [
	'^%',
    ],
);


1;
