package FS::InitHandler;

# this leaks memory under graceful restarts and i wouldn't use it on any
# modern server.  useful for very slow machines with memory to spare, just
# always do a full restart

use strict;
use vars qw($DEBUG);
use FS::UID qw(adminsuidsetup);
use FS::Record;

$DEBUG = 1;

sub handler {

  use Date::Format;
  use Date::Parse;
  use Tie::IxHash;
  use HTML::Entities;
  use IO::Handle;
  use IO::File;
  use String::Approx;
  use HTML::Widgets::SelectLayers 0.02;
  #use FS::UID;
  #use FS::Record;
  use FS::Conf;
  use FS::CGI;
  use FS::Msgcat;
  
  use FS::agent;
  use FS::agent_type;
  use FS::domain_record;
  use FS::cust_bill;
  use FS::cust_bill_pay;
  use FS::cust_credit;
  use FS::cust_credit_bill;
  use FS::cust_main;
  use FS::cust_main_county;
  use FS::cust_pay;
  use FS::cust_pkg;
  use FS::cust_refund;
  use FS::cust_svc;
  use FS::nas;
  use FS::part_bill_event;
  use FS::part_pkg;
  use FS::part_referral;
  use FS::part_svc;
  use FS::pkg_svc;
  use FS::port;
  use FS::queue;
  use FS::raddb;
  use FS::session;
  use FS::svc_acct;
  use FS::svc_acct_pop;
  use FS::svc_domain;
  use FS::svc_forward;
  use FS::svc_www;
  use FS::type_pkgs;
  use FS::part_export;
  use FS::part_export_option;
  use FS::export_svc;
  use FS::msgcat;

  warn "[FS::InitHandler] handler called\n" if $DEBUG;

  #this is sure to be broken on freebsd
  $> = $FS::UID::freeside_uid;

  open(MAPSECRETS,"<$FS::UID::conf_dir/mapsecrets")
    or die "can't read $FS::UID::conf_dir/mapsecrets: $!";

  my %seen;
  while (<MAPSECRETS>) {
    next if /^\s*(#|$)/;
    /^([\w\-\.]+)\s(.*)$/
      or do { warn "strange line in mapsecrets: $_"; next; };
    my($user, $datasrc) = ($1, $2);
    next if $seen{$datasrc}++;
    warn "[FS::InitHandler] preloading $datasrc for $user\n" if $DEBUG;
    adminsuidsetup($user);
  }

  close MAPSECRETS;

  #lalala probably broken on freebsd
  ($<, $>) = ($>, $<);
  $< = 0;

}

1;
