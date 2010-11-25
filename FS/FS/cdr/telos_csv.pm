package FS::cdr::telos_csv;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_min_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Telos (CSV)',
  'weight'        => 535,
  'header'        => 1,
  'import_fields' => [

    # Date (MM/DD/YY)
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d{1,2})\/(\d{1,2})\/(\d\d(\d\d)?)$/
            or die "unparsable date: $date";
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $2, $1-1, $3 );
        },

    # Time
    sub { my($cdr, $time) = @_;
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time";
          $cdr->enddate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },
    '', #RAS-Client
    sub { #Record-Type
      my($cdr, $rectype, $conf, $param) = @_;
      $param->{skiprow} = 1 if lc($rectype) ne 'stop';
    },
    skip(24), #Full-Name, Auth-Type, User-Name, NAS-IP-Address, NAS-Port,
              #Service-Type, Framed-Protocol, Framed-IP-Address, 
              #Framed-IP-Netmask, Framed-Routing, Filter-ID, Framed-MTU,
              #Framed-Compression, Login-IP-Host, Login-Service, Login-TCP-Port,
              #Callback-Number, Callback-ID, Framed-Route, Framed-IPX-Network,
              #Class, Session-Timeout, Idle-Timeout, Termination-Action
              #I told you it was a RADIUS log
    'dst', # Called-Station-ID, always 'X' in sample data
    'src', # Calling-Station-ID
    skip(8), #NAS-Identifier, Proxy-State, Acct-Status-Type, Acct-Delay-Time,
             #Acct-Input-Octets, Acct-Output-Octets, Acct-Session-Id, 
             #Acct-Authentic
    sub { 
      my ($cdr, $sec) = @_; 
      $cdr->duration($sec); 
      $cdr->billsec($sec);
      $cdr->startdate($cdr->enddate - $sec);
    },
    skip(75), #everything else
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
