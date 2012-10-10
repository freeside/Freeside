package FS::cdr::qwest;

use strict;
use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

my %disposition = (
  0 => 'ANSWERED',  #normal completed call
  1 => 'ANSWERED',  #"treated call"
  2 => 'NO ANSWER', #abandoned call
  3 => 'ERROR',     #abnormal call
  4 => 'ERROR',     #signaling system error
  5 => 'ANSWERED',  #forced disconnect
  6 => 'ANSWERED',  #off-net route advance
  7 => 'NO ANSWER', #test call
  8 => 'NO ANSWER', #recorded promotion
  9 => 'ERROR',     #TCAP DCP response time-out
  12=> 'ANSWERED',  #abnormal release
  13=> 'ERROR',     #"completed answer CDR"(?)
  15=> 'ERROR',     #"COS failure"(?)
);

my $startdate = _cdr_date_parser_maker('startdate');
my $enddate = _cdr_date_parser_maker('enddate');

%info = (
  'name'          => 'Qwest (Standard Daily)',
  'weight'        => 400,
  'type'          => 'fixedlength',
  'fixedlength_format' => [qw(
    billing_cycle_id:6:1:6
    discn_dt:8:7:14
    anstype:6:15:20
    pindigs:4:21:24
    origtime:6:25:30
    discn_time:6:31:36
    time_chng:1:37:37
    ani:15:38:52
    infodig:2:53:54
    calldur:11:55:65
    univacc:10:66:75
    compcode:6:76:81
    dialedno:15:82:96
    calledno:15:97:111
    predig:1:112:112
    seqnum:11:113:123
    orig_dt:8:124:131
    finsid:6:132:137
    trtmtcd:6:138:143
    anisuff:6:144:149
    origgrp:6:150:155
    origmem:6:156:161
    termgrp:6:162:167
    termmem:6:168:173
    fintkgrp:6:174:179
    billnum:24:180:203
    acctcd:12:204:215
    swid:6:216:221
    orig_bill_file_id:11:222:232
    orig_trunk_group_name:12:233:244
    orig_trunk_time_bias_ind:6:245:250
    term_trunk_group_name:12:251:262
    final_trunk_group_name:12:263:274
    orig_trunk_usage_ind:6:275:280
    orig_pricing_npa:3:281:283
    orig_pricing_nxx:3:284:286
    term_pricing_npa:3:287:289
    term_pricing_nxx:3:290:292
    prcmp_id:6:293:298
    component_group_cd:2:299:300
    component_group_val:24:301:324
    intra_lata_ind:1:325:325
    carrsel:1:326:326
    cic:6:327:332
    origlrn:10:333:342
    portedno:10:343:352
    lnpcheck:1:353:353
  )],
  'import_fields' => [
    '',                 # billing_cycle_id
    sub {               # discn_dt
      # hold onto this, combine it with discn_time later
      # YYYYMMDD
      my ($cdr, $data, $conf, $param) = @_;
      $param->{'discn_dt'} = $data;
      '';
    },
    '',                 # anstype
    '',                 # pindigs
    sub {               # orig_time
      # and this
      # hhmmss
      my ($cdr, $data, $conf, $param) = @_;
      $param->{'orig_time'} = $data;
      '';
    },
    sub {               # discn_time
      my ($cdr, $data, $conf, $param) = @_;
      $data = $param->{'discn_dt'} . $data; #YYYYMMDDhhmmss
      $enddate->($cdr, $data);
    },
    '',                 # time_chng
    'src',              # ani (originating number)
    '',                 # infodig
    'billsec',          # calldur
    '',                 # univacc
    sub {               # compcode
      my ($cdr, $data) = @_;
      my $compcode = sprintf('%d', $data);
      $cdr->disposition($disposition{$compcode});
      # only those that map to ANSWERED are billable, but that should be 
      # set in rating options, not enforced here
      '';
    },
    'dst',              # dialedno
    '',                 # calledno (physical terminating number)
    '',                 # predig (0/1/011 prefix)
    '',                 # seqnum
    sub {               # orig_dt
      # backward from the discn_ fields
      my ($cdr, $data, $conf, $param) = @_;
      $data .= $param->{'orig_time'};
      $startdate->($cdr, $data);
    },
    '',                 # finsid
    '',                 # trtmtcd
    '',                 # anisuff
    'channel',          # origgrp (orig. trunk group)
    '',                 # origmem (belongs in channel?)
    'dstchannel',       # termgrp (term. trunk group)
    '',                 # termmem (same?)
    '',                 # fintkgrp
    'charged_party',    # billnum (empty for "normal" calls)
    '',                 # acctcd
    '',                 # swid
    '',                 # orig_bill_file_id
    '',                 # orig_trunk_group_name
    '',                 # orig_trunk_time_bias_ind
    '',                 # term_trunk_group_name
    '',                 # final_trunk_group_name
    '',                 # orig_trunk_usage_ind
    '',                 # orig_pricing_npa
    '',                 # orig_pricing_nxx
    '',                 # term_pricing_npa
    '',                 # term_pricing_nxx
    '',                 # prcmp_id
    '',                 # component_group_cd
    '',                 # component_group_val
    '',                 # intra_lata_ind (or should we use this?)
    '',                 # carrsel
    '',                 # cic
    '',                 # origlrn
    '',                 # portedno
    '',                 # lnpcheck
  ],

);

1;
