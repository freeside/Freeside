package FS::cust_payby;
use base qw( FS::payinfo_Mixin FS::cust_main_Mixin FS::Record );

use strict;
use Business::CreditCard qw( validate cardtype );
use FS::UID qw( dbh );
use FS::Msgcat qw( gettext );
use FS::Record; #qw( qsearch qsearchs );
use FS::payby;
use FS::cust_main;
use FS::banned_pay;

our @encrypted_fields = ('payinfo', 'paycvv');
sub nohistory_fields { ('payinfo', 'paycvv'); }

our $ignore_expired_card = 0;
our $ignore_banned_card = 0;
our $ignore_invalid_card = 0;

our $conf;
install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
  $ignore_invalid_card = $conf->exists('allow_invalid_cards');
};

=head1 NAME

FS::cust_payby - Object methods for cust_payby records

=head1 SYNOPSIS

  use FS::cust_payby;

  $record = new FS::cust_payby \%hash;
  $record = new FS::cust_payby { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_payby object represents customer stored payment information.
FS::cust_payby inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item custpaybynum

primary key

=item custnum

custnum

=item weight

weight

=item payby

payby

=item payinfo

payinfo

=item paycvv

paycvv

=item paymask

paymask

=item paydate

paydate

=item paystart_month

paystart_month

=item paystart_year

paystart_year

=item payissue

payissue

=item payname

payname

=item paystate

paystate

=item paytype

paytype

=item payip

payip


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_payby'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->payby =~ /^(CARD|CHEK)$/ ) {
    # new auto card/check info, want to retry realtime_ invoice events
    #  (new customer?  that's okay, they won't have any)
    my $error = $self->cust_main->retry_realtime;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  if ( length($old->paycvv) && $self->paycvv =~ /^\s*[\*x]*\s*$/ ) {
    $self->paycvv($old->paycvv);
  }

  if ( $self->payby =~ /^(CARD|DCRD)$/
       && (    $self->payinfo =~ /xx/
            || $self->payinfo =~ /^\s*N\/A\s+\(tokenized\)\s*$/
          )
     )
  {
warn $self->payinfo;
warn $old->payinfo;
    $self->payinfo($old->payinfo);

  } elsif ( $self->payby =~ /^(CHEK|DCHK)$/ && $self->payinfo =~ /xx/ ) {
    #fix for #3085 "edit of customer's routing code only surprisingly causes
    #nothing to happen...
    # this probably won't do the right thing when we don't have the
    # public key (can't actually get the real $old->payinfo)
    my($new_account, $new_aba) = split('@', $self->payinfo);
    my($old_account, $old_aba) = split('@', $old->payinfo);
    $new_account = $old_account if $new_account =~ /xx/;
    $new_aba     = $old_aba     if $new_aba     =~ /xx/;
    $self->payinfo($new_account.'@'.$new_aba);
  }

  local($ignore_expired_card) = 1
    if $old->payby  =~ /^(CARD|DCRD)$/
    && $self->payby =~ /^(CARD|DCRD)$/
    && ( $old->payinfo eq $self->payinfo || $old->paymask eq $self->paymask );

  local($ignore_banned_card) = 1
    if (    $old->payby  =~ /^(CARD|DCRD)$/ && $self->payby =~ /^(CARD|DCRD)$/
         || $old->payby  =~ /^(CHEK|DCHK)$/ && $self->payby =~ /^(CHEK|DCHK)$/ )
    && ( $old->payinfo eq $self->payinfo || $old->paymask eq $self->paymask );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->payby =~ /^(CARD|CHEK)$/
       && ( ( $self->get('payinfo') ne $old->get('payinfo')
              && $self->get('payinfo') !~ /^99\d{14}$/ 
            )
            || grep { $self->get($_) ne $old->get($_) } qw(paydate payname)
          )
     )
  {

    # card/check/lec info has changed, want to retry realtime_ invoice events
    my $error = $self->cust_main->retry_realtime;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('custpaybynum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_numbern('weight')
    #encrypted #|| $self->ut_textn('payinfo')
    #encrypted #|| $self->ut_textn('paycvv')
#    || $self->ut_textn('paymask') #XXX something
    #later #|| $self->ut_textn('paydate')
    || $self->ut_numbern('paystart_month')
    || $self->ut_numbern('paystart_year')
    || $self->ut_numbern('payissue')
#    || $self->ut_textn('payname') #XXX something
    || $self->ut_alphan('paystate')
    || $self->ut_textn('paytype')
    || $self->ut_ipn('payip')
  ;
  return $error if $error;

  ### from cust_main

  FS::payby->can_payby($self->table, $self->payby)
    or return "Illegal payby: ". $self->payby;

  # If it is encrypted and the private key is not availaible then we can't
  # check the credit card.
  my $check_payinfo = ! $self->is_encrypted($self->payinfo);

  # Need some kind of global flag to accept invalid cards, for testing
  # on scrubbed data.
  #XXX if ( !$import && $check_payinfo && $self->payby =~ /^(CARD|DCRD)$/ ) {
  if ( !$ignore_invalid_card && 
    $check_payinfo && $self->payby =~ /^(CARD|DCRD)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16}|\d{8,9})$/
      or return gettext('invalid_card'); #. ": ". $self->payinfo;
    $payinfo = $1;
    $self->payinfo($payinfo);
    validate($payinfo)
      or return gettext('invalid_card'); # . ": ". $self->payinfo;

    return gettext('unknown_card_type')
      if $self->payinfo !~ /^99\d{14}$/ #token
      && cardtype($self->payinfo) eq "Unknown";

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_card'.
                 ': disabled from'. time2str('%a %h %o at %r', $ban->_date).
                 ' until '.         time2str('%a %h %o at %r', $ban->_end_date).
                 ' (ban# '. $ban->bannum. ')'
            unless $self->override_ban_warn;
        } else {
          return 'Banned credit card: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

    if (length($self->paycvv) && !$self->is_encrypted($self->paycvv)) {
      if ( cardtype($self->payinfo) eq 'American Express card' ) {
        $self->paycvv =~ /^(\d{4})$/
          or return "CVV2 (CID) for American Express cards is four digits.";
        $self->paycvv($1);
      } else {
        $self->paycvv =~ /^(\d{3})$/
          or return "CVV2 (CVC2/CID) is three digits.";
        $self->paycvv($1);
      }
    } else {
      $self->paycvv('');
    }

    my $cardtype = cardtype($payinfo);
    if ( $cardtype =~ /^(Switch|Solo)$/i ) {

      return "Start date or issue number is required for $cardtype cards"
        unless $self->paystart_month && $self->paystart_year or $self->payissue;

      return "Start month must be between 1 and 12"
        if $self->paystart_month
           and $self->paystart_month < 1 || $self->paystart_month > 12;

      return "Start year must be 1990 or later"
        if $self->paystart_year
           and $self->paystart_year < 1990;

      return "Issue number must be beween 1 and 99"
        if $self->payissue
          and $self->payissue < 1 || $self->payissue > 99;

    } else {
      $self->paystart_month('');
      $self->paystart_year('');
      $self->payissue('');
    }

  } elsif ( !$ignore_invalid_card && 
    $check_payinfo && $self->payby =~ /^(CHEK|DCHK)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/[^\d\@\.]//g;
    if ( $conf->config('echeck-country') eq 'CA' ) {
      $payinfo =~ /^(\d+)\@(\d{5})\.(\d{3})$/
        or return 'invalid echeck account@branch.bank';
      $payinfo = "$1\@$2.$3";
    } elsif ( $conf->config('echeck-country') eq 'US' ) {
      $payinfo =~ /^(\d+)\@(\d{9})$/ or return 'invalid echeck account@aba';
      $payinfo = "$1\@$2";
    } else {
      $payinfo =~ /^(\d+)\@(\d+)$/ or return 'invalid echeck account@routing';
      $payinfo = "$1\@$2";
    }
    $self->payinfo($payinfo);
    $self->paycvv('');

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_ach' unless $self->override_ban_warn;
        } else {
          return 'Banned ACH account: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

#  } elsif ( $self->payby eq 'PREPAY' ) {
#
#    my $payinfo = $self->payinfo;
#    $payinfo =~ s/\W//g; #anything else would just confuse things
#    $self->payinfo($payinfo);
#    $error = $self->ut_alpha('payinfo');
#    return "Illegal prepayment identifier: ". $self->payinfo if $error;
#    return "Unknown prepayment identifier"
#      unless qsearchs('prepay_credit', { 'identifier' => $self->payinfo } );
#    $self->paycvv('');

  }

  if ( $self->payby =~ /^(CHEK|DCHK)$/ ) {

    $self->paydate('');

  } elsif ( $self->payby =~ /^(CARD|DCRD)$/ ) {

    # shouldn't payinfo_check do this?
    return "Expiration date required"
      if $self->paydate eq '' || $self->paydate eq '-';

    my( $m, $y );
    if ( $self->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      ( $m, $y ) = ( $1, length($2) == 4 ? $2 : "20$2" );
    } elsif ( $self->paydate =~ /^19(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $2, "19$1" );
    } elsif ( $self->paydate =~ /^(20)?(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $3, "20$2" );
    } else {
      return "Illegal expiration date: ". $self->paydate;
    }
    $m = sprintf('%02d',$m);
    $self->paydate("$y-$m-01");
    my($nowm,$nowy)=(localtime(time))[4,5]; $nowm++; $nowy+=1900;
    return gettext('expired_card')
      if #XXX !$import
      #&&
         !$ignore_expired_card 
      && ( $y<$nowy || ( $y==$nowy && $1<$nowm ) );

  }

  if ( $self->payname eq '' && $self->payby !~ /^(CHEK|DCHK)$/ &&
       ( ! $conf->exists('require_cardname')
         || $self->payby !~ /^(CARD|DCRD)$/  ) 
  ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {

    if ( $self->payby =~ /^(CHEK|DCHK)$/ ) {
      $self->payname =~ /^([\w \,\.\-\']*)$/
        or return gettext('illegal_name'). " payname: ". $self->payname;
      $self->payname($1);
    } else {
      $self->payname =~ /^([\w \,\.\-\'\&]*)$/
        or return gettext('illegal_name'). " payname: ". $self->payname;
      $self->payname($1);
    }

  }

  ###

  $self->SUPER::check;
}

sub _banned_pay_hashref {
  my $self = shift;

  my %payby2ban = (
    'CARD' => 'CARD',
    'DCRD' => 'CARD',
    'CHEK' => 'CHEK',
    'DCHK' => 'CHEK'
  );

  {
    'payby'   => $payby2ban{$self->payby},
    'payinfo' => $self->payinfo,
    #don't ever *search* on reason! #'reason'  =>
  };
}

=item paydate_mon_year

Returns a two element list consisting of the paydate month and year.

=cut

sub paydate_mon_year {
  my $self = shift;

  my $date = $self->paydate; # || '12-2037';

  #false laziness w/elements/select-month_year.html
  if ( $date  =~ /^(\d{4})-(\d{1,2})-\d{1,2}$/ ) { #PostgreSQL date format
    ( $2, $1 );
  } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
    ( $1, $3 );
  } else {
    warn "unrecognized expiration date format: $date";
    ( '', '' );
  }

}

=item realtime_bop

=cut

sub realtime_bop {
  my( $self, %opt ) = @_;

  $opt{$_} = $self->$_() for qw( payinfo payname paydate );

  if ( $self->locationnum ) {
    my $cust_location = $self->cust_location;
    $opt{$_} = $cust_location->$_() for qw( address1 address2 city state zip );
  }

  $self->cust_main->realtime_bop({
    'method' => FS::payby->payby2bop( $self->payby ),
    %opt,
  });

}

=item paytypes

Returns a list of valid values for the paytype field (bank account type for
electronic check payment).

=cut

sub paytypes {
  #my $class = shift;

  ('', 'Personal checking', 'Personal savings', 'Business checking', 'Business savings');
}

=item cgi_cust_payby_fields

Returns the field names used in the web interface (including some pseudo-fields).

=cut

sub cgi_cust_payby_fields {
  #my $class = shift;
  [qw( payby payinfo paydate_month paydate_year paycvv payname weight
       payinfo1 payinfo2 payinfo3 paytype paystate payname_CHEK )];
}

=item cgi_hash_callback HASHREF

Subroutine (not a class or object method).  Processes a hash reference
of web interface contet (transfers the data from pseudo-fields to real fields).

=cut

sub cgi_hash_callback {
  my $hashref = shift;

  my %noauto = (
    'CARD' => 'DCRD',
    'CHEK' => 'DCHK',
  );
  $hashref->{payby} = $noauto{$hashref->{payby}}
    if ! $hashref->{weight} && exists $noauto{$hashref->{payby}};

  if ( $hashref->{payby} =~ /^(CHEK|DCHK)$/ ) {

    unless ( grep $hashref->{$_}, qw(payinfo1 payinfo2 payinfo3 payname_CHEK)) {
      %$hashref = ();
      return;
    }

    $hashref->{payinfo} = $hashref->{payinfo1}. '@';
    $hashref->{payinfo} .= $hashref->{payinfo3}.'.' 
      if $conf->config('echeck-country') eq 'CA';
    $hashref->{payinfo} .= $hashref->{'payinfo2'};

    $hashref->{payname} = $hashref->{'payname_CHEK'};

  } elsif ( $hashref->{payby} =~ /^(CARD|DCRD)$/ ) {

    unless ( grep $hashref->{$_}, qw( payinfo paycvv payname ) ) {
      %$hashref = ();
      return;
    }

  }

  $hashref->{paydate}= $hashref->{paydate_month}. '-'. $hashref->{paydate_year};

}

=item search_sql

Class method.

Returns a qsearch hash expression to search for parameters specified in HASHREF.
Valid paramters are:

=over 4

=item payby

listref

=item paydate_year

=item paydate_month


=back

=cut

sub search_sql {
  my ($class, $params) = @_;

  my @where = ();
  my $orderby;

  # initialize these to prevent warnings
  $params = {
    'paydate_year'  => '',
    %$params
  };

  ###
  # payby
  ###

  if ( $params->{'payby'} ) {

    my @payby = ref( $params->{'payby'} )
                  ? @{ $params->{'payby'} }
                  :  ( $params->{'payby'} );

    @payby = grep /^([A-Z]{4})$/, @payby;
    my $in_payby = 'IN(' . join(',', map {"'$_'"} @payby) . ')';
    push @where, "cust_payby.payby $in_payby"
      if @payby;
  }

  ###
  # paydate_year / paydate_month
  ###

  if ( $params->{'paydate_year'} =~ /^(\d{4})$/ ) {
    my $year = $1;
    $params->{'paydate_month'} =~ /^(\d\d?)$/
      or die "paydate_year without paydate_month?";
    my $month = $1;

    push @where,
      'cust_payby.paydate IS NOT NULL',
      "cust_payby.paydate != ''",
      "CAST(cust_payby.paydate AS timestamp) < CAST('$year-$month-01' AS timestamp )"
;
  }
  ##
  # setup queries, subs, etc. for the search
  ##

  $orderby ||= 'ORDER BY custnum';

  # here is the agent virtualization
  push @where,
    $FS::CurrentUser::CurrentUser->agentnums_sql(table => 'cust_main');

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = ' LEFT JOIN cust_main USING ( custnum ) ';
  # always make address fields available in results
  for my $pre ('bill_', 'ship_') {
    $addl_from .= 
      ' LEFT JOIN cust_location AS '.$pre.'location '.
      'ON (cust_main.'.$pre.'locationnum = '.$pre.'location.locationnum) ';
  }

  my $count_query = "SELECT COUNT(*) FROM cust_payby $addl_from $extra_sql";

  my @select = ( 'cust_payby.*',
                 #'cust_main.custnum',
                 # there's a good chance that we'll need these
                 'cust_main.bill_locationnum',
                 'cust_main.ship_locationnum',
                 FS::UI::Web::cust_sql_fields($params->{'cust_fields'}),
               );

  my $select = join(', ', @select);

  my $sql_query = {
    'table'         => 'cust_payby',
    'select'        => $select,
    'addl_from'     => $addl_from,
    'hashref'       => {},
    'extra_sql'     => $extra_sql,
    'order_by'      => $orderby,
    'count_query'   => $count_query,
  };
  $sql_query;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

