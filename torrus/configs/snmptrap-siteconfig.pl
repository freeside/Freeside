# Torrus SNMP Trap configuration. Put all your site specifics here.

# Hosts that will receive traps
@Torrus::Snmptrap::hosts = qw( localhost );

# SNMP community for trap sending
$Torrus::Snmptrap::community = 'public';

# SNMP trap port.
$Torrus::Snmptrap::port = 162;


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
