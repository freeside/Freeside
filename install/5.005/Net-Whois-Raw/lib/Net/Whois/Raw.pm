package Net::Whois::Raw;

require Net::Whois::Raw::Data;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $OMIT_MSG $CHECK_FAIL
	%notfound %strip $CACHE_DIR $CACHE_TIME $USE_CNAMES
	$TIMEOUT);
use IO::Socket;

require Exporter;

@ISA = qw(Exporter);

@EXPORT    = qw( whois whois_config ); ### It's bad manners to export lots.
@EXPORT_OK = qw( $OMIT_MSG $CHECK_FAIL $CACHE_DIR $CACHE_TIME $USE_CNAMES $TIMEOUT);

$VERSION = '0.31';

($OMIT_MSG, $CHECK_FAIL, $CACHE_DIR, $CACHE_TIME, $USE_CNAMES, $TIMEOUT) = (0) x 6;

sub whois {
    my ($dom, $srv) = @_;
    my $res;
    unless ($srv) {
        ($res, $srv) = query($dom);
    } else {
        $res = _whois($dom, uc($srv));
    }
    finish($res, $srv);
}

sub whois_config {
    my ($par) = @_;
    my @parnames = qw(OMIT_MSG CHECK_FAIL CACHE_DIR CACHE_TIME USE_CNAMES TIMEOUT);
    foreach my $parname (@parnames) {
	if (exists($par->{$parname})) {
	    eval('$'.$parname.'='.int($par->{$parname}));
	}
    }
}

sub query {
    my $dom = shift;
    my $tld;
    if ($dom =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
        $tld = "IP";
    } else { 
	my @alltlds = keys %Net::Whois::Raw::Data::servers;
	@alltlds = sort { dlen($b) <=> dlen($a) } @alltlds;
	foreach my $awailtld (@alltlds) {
	    $awailtld = lc $awailtld;
	    if ($dom =~ /(.+?)\.($awailtld)$/) {
		$tld = uc $2;
		last;
	    }
	}
	unless ($tld) {
	    my @tokens = split(/\./, $dom);
    	    $tld = uc($tokens[-1]); 
	}
    }


    $dom =~ s/.NS$//i;
    my $cname = "$tld.whois-servers.net";
    my $srv = $Net::Whois::Raw::Data::servers{$tld} || $cname;
    $srv = $cname if $USE_CNAMES && gethostbyname($cname);
    my $flag = (
	$srv eq 'whois.crsnic.net' ||
	$srv eq 'whois.publicinterestregistry.net' ||
	$srv eq 'whois.nic.cc' ||
	$tld eq 'ARPA'
    );
    my $res = do_whois($dom, uc($srv), $flag, [], $tld);
    wantarray ? ($res, $srv) : $res;
}

sub do_whois {
    my ($dom) = @_; # receives 4 parameters, do NOT shift
    return _whois(@_) unless $CACHE_DIR;
    mkdir $CACHE_DIR, 0644;
    if (-f "$CACHE_DIR/$dom") {
        if (open(I, "$CACHE_DIR/$dom")) {
            my $res = join("", <I>);
            close(I);
            return $res;
        }
    }
    my $res = _whois(@_);
    return $res unless $res;
    return $res unless open(O, ">$CACHE_DIR/$dom");
    print O $res;
    close(O);


    return $res unless $CACHE_TIME;

    my $now = time;
    foreach (glob("$CACHE_DIR/*.*")) {
        my $atime = (stat($_))[8];
        my $elapsed = $now - $atime;
        unlink $_ if ($elapsed / 3600 > $CACHE_TIME); 
    }
    $res;
}

sub finish {
    my ($text, $srv) = @_;
    return $text unless $CHECK_FAIL || $OMIT_MSG;
    *notfound = \%Net::Whois::Raw::Data::notfound;
    *strip = \%Net::Whois::Raw::Data::strip;

    my $notfound = $notfound{lc($srv)};
    my @strip = $strip{lc($srv)} ? @{$strip{lc($srv)}} : ();
    my @lines;
    MAIN: foreach (split(/\n/, $text)) {
        return undef if $CHECK_FAIL && $notfound && /$notfound/;
        if ($OMIT_MSG) {
            foreach my $re (@strip) {
                next MAIN if (/$re/);
            }
        }
        push(@lines, $_);
    }
    local ($_) = join("\n", @lines, "");

    if ($CHECK_FAIL > 1) {
	return undef unless check_existance($_);
    }

    if ($OMIT_MSG > 1) {	
        s/The Data.+(policy|connection)\.\n//is;
        s/% NOTE:.+prohibited\.//is;
        s/Disclaimer:.+\*\*\*\n?//is;
        s/NeuLevel,.+A DOMAIN NAME\.//is;
        s/For information about.+page=spec//is;
        s/NOTICE: Access to.+this policy.//is;
        s/The previous information.+completeness\.//s;
        s/NOTICE AND TERMS OF USE:.*modify these terms at any time\.//s;
        s/TERMS OF USE:.*?modify these terms at any time\.//s;
        s/NOTICE:.*expiration for this registration\.//s;

	s/By submitting a WHOIS query.+?DOMAIN AVAILABILITY.\n?//s;
	s/Registration and WHOIS.+?its accuracy.\n?//s;
        s/Disclaimer:.+?\*\*\*\n?//s;
	s/The .COOP Registration .+ Information\.//s;
	s/Whois Server Version \d+\.\d+.//is;
	s/NeuStar,.+www.whois.us\.//is;
        s/\n?Domain names in the \.com, .+ detailed information.\n?//s;
        s/\n?The Registry database .+?Registrars\.\n//s;
        s/\n?>>> Last update of .+? <<<\n?//;
        s/% .+?\n//gs;
    }
    $_;
}

sub _whois {
    my ($dom, $srv, $flag, $ary, $tld) = @_;
    my $state;

    my $sock;
    eval {
        local $SIG{'ALRM'} = sub { die "Connection timeout to $srv" };
        alarm $TIMEOUT if $TIMEOUT;
        $sock = new IO::Socket::INET("$srv:43") || die "$srv: $!";
    };
    alarm 0;
    die $@ if $@;
    my $israce = $dom =~ /ra--/ || $dom =~ /bq--/;
    my $whoisquery = $dom;
    if ($srv eq 'WHOIS.MELBOURNEIT.COM' && $israce) {
	$whoisquery .= ' race';
    }
    #warn "$srv: $whoisquery ($OMIT_MSG, $CHECK_FAIL, $CACHE_DIR, $CACHE_TIME, $USE_CNAMES, $TIMEOUT)\n";
    print $sock "$whoisquery\r\n";
    my @lines = <$sock>;
    close($sock);
    my $answer = join '', @lines;
    if ($flag) {
        foreach (@lines) {
            $state ||= (/Registrar:/);
            if ( $state && /Whois Server:\s*([A-Za-z0-9\-_\.]+)/ ) {
                my $newsrv = uc("$1");
                next if (($newsrv) eq uc($srv));
                return undef if (grep {$_ eq $newsrv} @$ary);
		my $whois = eval { _whois($dom, $newsrv, $flag, [@$ary, $srv]) };
		if ($@ && !$whois || $whois && !check_existance($whois)) {
		    return $answer;
		}
                return $whois;
            }
            if (/^\s+Maintainer:\s+RIPE\b/ && $tld eq 'ARPA') {
                my $newsrv = uc($Net::Whois::Raw::Data::servers{'RIPE'});
                next if ($newsrv eq $srv);
                return undef if (grep {$_ eq $newsrv} @$ary);
                my $whois = eval { _whois($dom, $newsrv, $flag, [@$ary, $srv]) };
		if ($@ && !$whois) {
		    return $answer;
		}
                return $whois;
            }
        }
    }
    my $whois = join("", @lines);

    if ($whois =~ /To single out one record, look it up with \"xxx\",/s) {
        my $newsrv = uc('whois.networksolutions.com');
        return _whois($dom, $newsrv, $flag, [@{$ary||[]}, $srv]);
    }
    
    return $whois;
}

sub dlen {
    my ($str) = @_;
    my $dotcount = $str =~ tr/././;
    return length($str) * (1 + $dotcount);
}


sub check_existance {
    $_ = $_[0];

    return undef if
	/is unavailable/is ||
	/No entries found for the selected source/is ||
	/Not found:/s ||
	/No match\./s ||
	/is available/is ||
	/Not found/is &&
	    !/ your query returns "NOT FOUND"/ &&
	    !/Domain not found locally/ ||
	/No match for/is ||
	/No Objects Found/s ||
	/No domain records were found/s ||
	/No such domain/s ||
	/No entries found in the /s ||
	/Unable to find any information for your query/s ||
	/is not registered and may be available for registration/s;
    return 1;
}


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Net::Whois::Raw - Perl extension for unparsed raw whois information

=head1 SYNOPSIS

  use Net::Whois::Raw qw( whois );
  
  $s = whois('perl.com');
  $s = whois('funet.fi');
  $s = whois('yahoo.co.uk');

	### if you do "use Net::Whois::Raw qw( whois $OMIT_MSG $CHECK_FAIL 
	###              $CACHE_DIR $CACHE_TIME $USE_CNAMES $TIMEOUT );
	### you can use these:

  $OMIT_MSG = 1; # This will attempt to strip several known copyright
		messages and disclaimers sorted by servers.
		Default is to give the whole response.

  $OMIT_MSG = 2; # This will try some additional stripping rules
		if none are known for the spcific server.

  $CHECK_FAIL = 1; # This will return undef if the response matches
		one of the known patterns for a failed search,
		sorted by servers.
		Default is to give the textual response.

  $CHECK_FAIL = 2; # This will match against several more rules
		if none are known for the specific server.

  $CACHE_DIR = "/var/spool/pwhois/"; # Whois information will be
		cached in this directory. Default is no cache.

  $CACHE_TIME = 24; # Cache files will be cleared after not accessed
		for a specific number of hours. Documents will not be
		cleared if they keep get requested for, independent
		of disk space. Default is not to clear the cache.

  $USE_CNAMES = 1; # Use whois-servers.net to get the whois server
		name when possible. Default is to use the 
		hardcoded defaults.


  $TIMEOUT = 10; # Cancel the request if connection is not made within
		a specific number of seconds.

  Note: as of version 0.21, extra data will be loaded only if the
  OMIT_MSG or CHECK_FAIL flags were used, in order to reduce memory usage.

=head1 DESCRIPTION

Net::Whois::Raw queries NetworkSolutions and follows the Registrar: answer
for ORG, EDU, COM and NET domains.
For other TLDs it uses the whois-servers.net namespace.
(B<$TLD>.whois-servers.net).

Setting the variables $OMIT_MSG and $CHECK_FAIL will match the results
against a set of known patterns. The first flag will try to omit the
copyright message/disclaimer, the second will attempt to determine if
the search failed and return undef in such a case.

B<IMPORTANT>: these checks merely use pattern matching; they will work
on several servers but certainly not on all of them.

(This features were contributed by Walery Studennikov B<despair@sama.ru>)

=head1 AUTHOR

Original author Ariel Brosh, B<schop@cpan.org>, 
Inspired by jwhois.pl available on the net.

Since Ariel has passed away in September 2002:

Past maintainers Gabor Szabo, B<gabor@perl.org.il>,
Corris Randall B<corris@cpan.org>

Current Maintainer: Walery Studennikov B<despair@cpan.org>

=head1 CREDITS

Fixed regular expression to match hyphens. (Peter Chow,
B<peter@interq.or.jp>)

Added support for Tonga TLD. (.to) (Peter Chow, B<peter@interq.or.jp>)

Added support for reverse lookup of IP addresses via the ARIN registry. (Alex Withers B<awithers@gonzaga.edu>)

This will work now for RIPE addresses as well, according to a redirection from ARIN. (Philip Hands B<phil@uk.alcove.com>, Trevor Peirce B<trev@digitalcon.ca>)

Added the pattern matching switches, (Walery Studennikov B<despair@sama.ru>)

Modified pattern matching, added cache. (Tony L. Svanstrom B<tony@svanstrom.org>)

=head1 CHANGES

See file "Changes" in the distribution


=head1 CLARIFICATION

As NetworkSolutions got most of the domains of InterNic as legacy, we
start by querying their server, as this way one whois query would be
sufficient for many domains. Starting at whois.internic.net or
whois.crsnic.net will result in always two requests in any case.

=head1 NOTE

Some users complained that the B<die> statements in the module make their
CGI scripts crash. Please consult the entries on B<eval> and
B<die> on L<perlfunc> about exception handling in Perl.

=head1 COPYRIGHT

Copyright 2000-2002 Ariel Brosh.
Copyright 2003-2003 Gabor Szabo.
Copyright 2003-2003 Corris Randall.
Copyright 2003-2003 Walery Studennikov.

This package is free software. You may redistribute it or modify it under
the same terms as Perl itself.

I apologize for any misunderstandings caused by the lack of a clear
licence in previous versions.

=head1 COMMERCIAL SUPPORT

Not available anymore.

=head1 LEGAL

Notice that registrars forbid querying their whois servers as a part of
a search engine, or querying for a lot of domains by script. 
Also, omitting the copyright information (that was requested by users of this 
module) is forbidden by the registrars.

=head1 SEE ALSO

L<perl(1)>, L<Net::Whois>, L<whois>.

=cut
