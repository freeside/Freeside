package FS::ClientAPI::MyAccount;

use strict;
use vars qw($cache);
use subs qw(_cache);
use Digest::MD5 qw(md5_hex);
use Date::Format;
use Business::CreditCard;
use Time::Duration;
use FS::CGI qw(small_custview); #doh
use FS::Conf;
use FS::Record qw(qsearch qsearchs);
use FS::Msgcat qw(gettext);
use FS::ClientAPI_SessionCache;
use FS::svc_acct;
use FS::svc_domain;
use FS::svc_external;
use FS::part_svc;
use FS::cust_main;
use FS::cust_bill;
use FS::cust_main_county;
use FS::cust_pkg;

use vars qw( @cust_main_editable_fields );
@cust_main_editable_fields = qw(
  first last company address1 address2 city
    county state zip country daytime night fax
  ship_first ship_last ship_company ship_address1 ship_address2 ship_city
    ship_state ship_zip ship_country ship_daytime ship_night ship_fax
  payby payinfo payname
);

use subs qw(_provision);

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::MyAccount',
             } );
}

#false laziness w/FS::ClientAPI::passwd::passwd
sub login {
  my $p = shift;

  my $svc_domain = qsearchs('svc_domain', { 'domain' => $p->{'domain'} } )
    or return { error => 'Domain '. $p->{'domain'}. ' not found' };

  my $svc_acct = qsearchs( 'svc_acct', { 'username'  => $p->{'username'},
                                         'domsvc'    => $svc_domain->svcnum, }
                         );
  return { error => 'User not found.' } unless $svc_acct;

  my $conf = new FS::Conf;
  my $pkg_svc = $svc_acct->cust_svc->pkg_svc;
  return { error => 'Only primary user may log in.' } 
    if $conf->exists('selfservice_server-primary_only')
       && ( ! $pkg_svc || $pkg_svc->primary_svc ne 'Y' );

  return { error => 'Incorrect password.' }
    unless $svc_acct->check_password($p->{'password'});

  my $session = {
    'svcnum' => $svc_acct->svcnum,
  };

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    my $cust_main = $cust_pkg->cust_main;
    $session->{'custnum'} = $cust_main->custnum;
  }

  my $session_id;
  do {
    $session_id = md5_hex(md5_hex(time(). {}. rand(). $$))
  } until ( ! defined _cache->get($session_id) ); #just in case

  _cache->set( $session_id, $session, '1 hour' );

  return { 'error'      => '',
           'session_id' => $session_id,
         };
}

sub logout {
  my $p = shift;
  if ( $p->{'session_id'} ) {
    _cache->remove($p->{'session_id'});
    return { 'error' => '' };
  } else {
    return { 'error' => "Can't resume session" }; #better error message
  }
}

sub customer_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my %return;
  if ( $custnum ) { #customer record

    my $search = { 'custnum' => $custnum };
    $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
    my $cust_main = qsearchs('cust_main', $search )
      or return { 'error' => "unknown custnum $custnum" };

    $return{balance} = $cust_main->balance;

    my @open = map {
                     {
                       invnum => $_->invnum,
                       date   => time2str("%b %o, %Y", $_->_date),
                       owed   => $_->owed,
                     };
                   } $cust_main->open_cust_bill;
    $return{open_invoices} = \@open;

    my $conf = new FS::Conf;
    $return{small_custview} =
      small_custview( $cust_main, $conf->config('countrydefault') );

    $return{name} = $cust_main->first. ' '. $cust_main->get('last');

    for (@cust_main_editable_fields) {
      $return{$_} = $cust_main->get($_);
    }

    if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
      $return{payinfo} = $cust_main->payinfo_masked;
      @return{'month', 'year'} = $cust_main->paydate_monthyear;
    }

    $return{'invoicing_list'} =
      join(', ', grep { $_ !~ /^(POST|FAX)$/ } $cust_main->invoicing_list );
    $return{'postal_invoicing'} =
      0 < ( grep { $_ eq 'POST' } $cust_main->invoicing_list );

  } elsif ( $session->{'svcnum'} ) { #no customer record

    my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $session->{'svcnum'} } )
      or die "unknown svcnum";
    $return{name} = $svc_acct->email;

  } else {

    return { 'error' => 'Expired session' }; #XXX redirect to login w/this err!

  }

  return { 'error'          => '',
           'custnum'        => $custnum,
           %return,
         };

}

sub edit_info {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'}
    or return { 'error' => "no customer record" };

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $new = new FS::cust_main { $cust_main->hash };
  $new->set( $_ => $p->{$_} )
    foreach grep { exists $p->{$_} } @cust_main_editable_fields;

  if ( $p->{'payby'} =~ /^(CARD|DCRD)$/ ) {
    $new->paydate($p->{'year'}. '-'. $p->{'month'}. '-01');
    if ( $new->payinfo eq $cust_main->payinfo_masked ) {
      $new->payinfo($cust_main->payinfo);
    } else {
      $new->paycvv($p->{'paycvv'});
    }
  }

  my @invoicing_list;
  if ( exists $p->{'invoicing_list'} || exists $p->{'postal_invoicing'} ) {
    #false laziness with httemplate/edit/process/cust_main.cgi
    @invoicing_list = split( /\s*\,\s*/, $p->{'invoicing_list'} );
    push @invoicing_list, 'POST' if $p->{'postal_invoicing'};
  } else {
    @invoicing_list = $cust_main->invoicing_list;
  }

  my $error = $new->replace($cust_main, \@invoicing_list);
  return { 'error' => $error } if $error;
  #$cust_main = $new;
  
  return { 'error' => '' };
}

sub payment_info {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  ##
  #generic
  ##

  my $conf = new FS::Conf;
  my %states = map { $_->state => 1 }
                 qsearch('cust_main_county', {
                   'country' => $conf->config('countrydefault') || 'US'
                 } );

  use vars qw($payment_info); #cache for performance
  $payment_info ||= {

    #list all counties/states/countries
    'cust_main_county' => 
      [ map { $_->hashref } qsearch('cust_main_county', {}) ],

    #shortcut for one-country folks
    'states' =>
      [ sort { $a cmp $b } keys %states ],

    'card_types' => {
      'VISA' => 'VISA card',
      'MasterCard' => 'MasterCard',
      'Discover' => 'Discover card',
      'American Express' => 'American Express card',
    },

  };

  ##
  #customer-specific
  ##

  my %return = %$payment_info;

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  $return{balance} = $cust_main->balance;

  $return{payname} = $cust_main->payname
                     || ( $cust_main->first. ' '. $cust_main->get('last') );

  $return{$_} = $cust_main->get($_) for qw(address1 address2 city state zip);

  $return{payby} = $cust_main->payby;

  if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
    #warn $return{card_type} = cardtype($cust_main->payinfo);
    $return{payinfo} = $cust_main->payinfo;

    @return{'month', 'year'} = $cust_main->paydate_monthyear;

  }

  #doubleclick protection
  my $_date = time;
  $return{paybatch} = "webui-MyAccount-$_date-$$-". rand() * 2**32;

  return { 'error' => '',
           %return,
         };

};

#some false laziness with httemplate/process/payment.cgi - look there for
#ACH and CVV support stuff
sub process_payment {

  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my %return;

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  $p->{'payname'} =~ /^([\w \,\.\-\']+)$/
    or return { 'error' => gettext('illegal_name'). " payname: ". $p->{'payname'} };
  my $payname = $1;

  $p->{'paybatch'} =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
    or return { 'error' => gettext('illegal_text'). " paybatch: ". $p->{'paybatch'} };
  my $paybatch = $1;

  my $payinfo;
  my $paycvv = '';
  #if ( $payby eq 'CHEK' ) {
  #
  #  $p->{'payinfo1'} =~ /^(\d+)$/
  #    or return { 'error' => "illegal account number ". $p->{'payinfo1'} };
  #  my $payinfo1 = $1;
  #   $p->{'payinfo2'} =~ /^(\d+)$/
  #    or return { 'error' => "illegal ABA/routing number ". $p->{'payinfo2'} };
  #  my $payinfo2 = $1;
  #  $payinfo = $payinfo1. '@'. $payinfo2;
  # 
  #} elsif ( $payby eq 'CARD' ) {
   
    $payinfo = $p->{'payinfo'};
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16})$/
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    $payinfo = $1;
    validate($payinfo)
      or return { 'error' => gettext('invalid_card') }; # . ": ". $self->payinfo
    return { 'error' => gettext('unknown_card_type') }
      if cardtype($payinfo) eq "Unknown";

    if ( defined $cust_main->dbdef_table->column('paycvv') ) {
      if ( length($p->{'paycvv'} ) ) {
        if ( cardtype($payinfo) eq 'American Express card' ) {
          $p->{'paycvv'} =~ /^(\d{4})$/
            or return { 'error' => "CVV2 (CID) for American Express cards is four digits." };
          $paycvv = $1;
        } else {
          $p->{'paycvv'} =~ /^(\d{3})$/
            or return { 'error' => "CVV2 (CVC2/CID) is three digits." };
          $paycvv = $1;
        }
      }
    }
  
  #} else {
  #  die "unknown payby $payby";
  #}

  my $error = $cust_main->realtime_bop( 'CC', $p->{'amount'},
    'quiet'    => 1,
    'payinfo'  => $payinfo,
    'paydate'  => $p->{'year'}. '-'. $p->{'month'}. '-01',
    'payname'  => $payname,
    'paybatch' => $paybatch,
    'paycvv'   => $paycvv,
    map { $_ => $p->{$_} } qw( address1 address2 city state zip )
  );
  return { 'error' => $error } if $error;

  $cust_main->apply_payments;

  if ( $p->{'save'} ) {
    my $new = new FS::cust_main { $cust_main->hash };
    $new->set( $_ => $p->{$_} )
      foreach qw( payname address1 address2 city state zip payinfo );
    $new->set( 'paydate' => $p->{'year'}. '-'. $p->{'month'}. '-01' );
    $new->set( 'payby' => $p->{'auto'} ? 'CARD' : 'DCRD' );
    my $error = $new->replace($cust_main);
    return { 'error' => $error } if $error;
    $cust_main = $new;
  }

  return { 'error' => '' };

}

sub process_prepay {

  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my %return;

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my( $amount, $seconds ) = ( 0, 0 );
  my $error = $cust_main->recharge_prepay( $p->{'prepaid_cardnum'},
                                           \$amount,
                                           \$seconds
                                         );

  return { 'error' => $error } if $error;

  return { 'error'    => '',
           'amount'   => $amount,
           'seconds'  => $seconds,
           'duration' => duration_exact($seconds),
         };

}

sub invoice {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $invnum = $p->{'invnum'};

  my $cust_bill = qsearchs('cust_bill', { 'invnum'  => $invnum,
                                          'custnum' => $custnum } )
    or return { 'error' => "Can't find invnum" };

  #my %return;

  return { 'error'        => '',
           'invnum'       => $invnum,
           'invoice_text' => join('', $cust_bill->print_text ),
         };

}

sub list_invoices {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my @cust_bill = $cust_main->cust_bill;

  return  { 'error'       => '',
            'invoices'    =>  [ map { { 'invnum' => $_->invnum,
                                        '_date'  => $_->_date,
                                      }
                                    } @cust_bill
                              ]
          };
}

sub cancel {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my @errors = $cust_main->cancel( 'quiet'=>1 );

  my $error = scalar(@errors) ? join(' / ', @errors) : '';

  return { 'error' => $error };

}

sub list_pkgs {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  #return { 'cust_pkg' => [ map { $_->hashref } $cust_main->ncancelled_pkgs ] };

  my $conf = new FS::Conf;

  { 'svcnum'   => $session->{'svcnum'},
    'custnum'  => $custnum,
    'cust_pkg' => [ map {
                          { $_->hash,
                            $_->part_pkg->hash,
                            part_svc =>
                              [ map $_->hashref, $_->available_part_svc ],
                            cust_svc => 
                              [ map { my $ref = { $_->hash,
                                                  label => [ $_->label ],
                                                };
                                      $ref->{_password} = $_->svc_x->_password
                                        if $context eq 'agent'
                                        && $conf->exists('agent-showpasswords')
                                        && $_->part_svc->svcdb eq 'svc_acct';
                                      $ref;
                                    } $_->cust_svc
                              ],
                          };
                        } $cust_main->ncancelled_pkgs
                  ],
    'small_custview' =>
      small_custview( $cust_main, $conf->config('countrydefault') ),
  };

}

sub order_pkg {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  #false laziness w/ClientAPI/Signup.pm

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum' => $custnum,
    'pkgpart' => $p->{'pkgpart'},
  } );
  my $error = $cust_pkg->check;
  return { 'error' => $error } if $error;

  my @svc = ();
  unless ( $p->{'svcpart'} eq 'none' ) {

    my $svcdb;
    my $svcpart = '';
    if ( $p->{'svcpart'} =~ /^(\d+)$/ ) {
      $svcpart = $1;
      my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
      return { 'error' => "Unknown svcpart $svcpart" } unless $part_svc;
      $svcdb = $part_svc->svcdb;
    } else {
      $svcdb = 'svc_acct';
    }
    $svcpart ||= $cust_pkg->part_pkg->svcpart($svcdb);

    my %fields = (
      'svc_acct'     => [ qw( username _password sec_phrase popnum ) ],
      'svc_domain'   => [ qw( domain ) ],
      'svc_external' => [ qw( id title ) ],
    );
  
    my $svc_x = "FS::$svcdb"->new( {
      'svcpart'   => $svcpart,
      map { $_ => $p->{$_} } @{$fields{$svcdb}}
    } );
    
    if ( $svcdb eq 'svc_acct' ) {
      my @acct_snarf;
      my $snarfnum = 1;
      while ( length($p->{"snarf_machine$snarfnum"}) ) {
        my $acct_snarf = new FS::acct_snarf ( {
          'machine'   => $p->{"snarf_machine$snarfnum"},
          'protocol'  => $p->{"snarf_protocol$snarfnum"},
          'username'  => $p->{"snarf_username$snarfnum"},
          '_password' => $p->{"snarf_password$snarfnum"},
        } );
        $snarfnum++;
        push @acct_snarf, $acct_snarf;
      }
      $svc_x->child_objects( \@acct_snarf );
    }
    
    my $y = $svc_x->setdefault; # arguably should be in new method
    return { 'error' => $y } if $y && !ref($y);
  
    $error = $svc_x->check;
    return { 'error' => $error } if $error;

    push @svc, $svc_x;

  }

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => \@svc );
  #msgcat
  $error = $cust_main->order_pkgs( \%hash, '', 'noexport' => 1 );
  return { 'error' => $error } if $error;

  my $conf = new FS::Conf;
  if ( $conf->exists('signup_server-realtime') ) {

    my $old_balance = $cust_main->balance;

    my $bill_error = $cust_main->bill;
    $cust_main->apply_payments;
    $cust_main->apply_credits;
    $bill_error = $cust_main->collect;

    if (    $cust_main->balance > $old_balance
         && $cust_main->balance > 0
         && $cust_main->payby !~ /^(BILL|DCRD|DCHK)$/ ) {
      #this makes sense.  credit is "un-doing" the invoice
      $cust_main->credit( sprintf("%.2f", $cust_main->balance - $old_balance ),
                          'self-service decline' );
      $cust_main->apply_credits( 'order' => 'newest' );

      $cust_pkg->cancel('quiet'=>1);
      return { 'error' => '_decline', 'bill_error' => $bill_error };
    } else {
      $cust_pkg->reexport;
    }

  } else {
    $cust_pkg->reexport;
  }

  return { error => '', pkgnum => $cust_pkg->pkgnum };

}

sub cancel_pkg {
  my $p = shift;
  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,   } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $error = $cust_pkg->cancel( 'quiet'=>1 );
  return { 'error' => $error };

}

sub provision_acct {
  my $p = shift;

  return { 'error' => gettext('passwords_dont_match') }
    if $p->{'_password'} ne $p->{'_password2'};
  return { 'error' => gettext('empty_password') }
    unless length($p->{'_password'});

  _provision( 'FS::svc_acct',
              [qw(username _password)],
              [qw(username _password)],
              $p,
              @_
            );
}

sub provision_external {
  my $p = shift;
  #_provision( 'FS::svc_external', [qw(id title)], [qw(id title)], $p, @_ );
  _provision( 'FS::svc_external',
              [],
              [qw(id title)],
              $p,
              @_
            );
}

sub _provision {
  my( $class, $fields, $return_fields, $p ) = splice(@_, 0, 4);

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,
                                                               } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $part_svc = qsearchs('part_svc', { 'svcpart' => $p->{'svcpart'} } )
    or return { 'error' => "unknown svcpart $p->{'svcpart'}" };

  my $svc_x = $class->new( {
    'pkgnum'  => $p->{'pkgnum'},
    'svcpart' => $p->{'svcpart'},
    map { $_ => $p->{$_} } @$fields
  } );
  my $error = $svc_x->insert;
  $svc_x = qsearchs($svc_x->table, { 'svcnum' => $svc_x->svcnum })
    unless $error;

  return { 'svc'   => $part_svc->svc,
           'error' => $error,
           map { $_ => $svc_x->get($_) } @$return_fields
         };

}

sub part_svc_info {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $pkgnum = $p->{'pkgnum'};

  my $cust_pkg = qsearchs('cust_pkg', { 'custnum' => $custnum,
                                        'pkgnum'  => $pkgnum,
                                                               } )
    or return { 'error' => "unknown pkgnum $pkgnum" };

  my $svcpart = $p->{'svcpart'};

  my $pkg_svc = qsearchs('pkg_svc', { 'pkgpart' => $cust_pkg->pkgpart,
                                      'svcpart' => $svcpart,           } )
    or return { 'error' => "unknown svcpart $svcpart for pkgnum $pkgnum" };
  my $part_svc = $pkg_svc->part_svc;

  my $conf = new FS::Conf;

  return {
    'svc'     => $part_svc->svc,
    'svcdb'   => $part_svc->svcdb,
    'pkgnum'  => $pkgnum,
    'svcpart' => $svcpart,
    'custnum' => $custnum,

    'security_phrase' => 0, #XXX !
    'svc_acct_pop'    => [], #XXX !
    'popnum'          => '',
    'init_popstate'   => '',
    'popac'           => '',
    'acstate'         => '',

    'small_custview' =>
      small_custview( $cust_main, $conf->config('countrydefault') ),

  };

}

sub unprovision_svc {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $search = { 'custnum' => $custnum };
  $search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  my $cust_main = qsearchs('cust_main', $search )
    or return { 'error' => "unknown custnum $custnum" };

  my $svcnum = $p->{'svcnum'};

  my $cust_svc = qsearchs('cust_svc', { 'svcnum'  => $svcnum, } )
    or return { 'error' => "unknown svcnum $svcnum" };

  return { 'error' => "Service $svcnum does not belong to customer $custnum" }
    unless $cust_svc->cust_pkg->custnum == $custnum;

  my $conf = new FS::Conf;

  return { 'svc'   => $cust_svc->part_svc->svc,
           'error' => $cust_svc->cancel,
           'small_custview' =>
             small_custview( $cust_main, $conf->config('countrydefault') ),
         };

}

#--

sub _custoragent_session_custnum {
  my $p = shift;

  my($context, $session, $custnum);
  if ( $p->{'session_id'} ) {

    $context = 'customer';
    $session = _cache->get($p->{'session_id'})
      or return ( 'error' => "Can't resume session" ); #better error message
    $custnum = $session->{'custnum'};

  } elsif ( $p->{'agent_session_id'} ) {

    $context = 'agent';
    my $agent_cache = new FS::ClientAPI_SessionCache( {
      'namespace' => 'FS::ClientAPI::Agent',
    } );
    $session = $agent_cache->get($p->{'agent_session_id'})
      or return ( 'error' => "Can't resume session" ); #better error message
    $custnum = $p->{'custnum'};

  } else {
    return ( 'error' => "Can't resume session" ); #better error message
  }

  ($context, $session, $custnum);

}

1;

