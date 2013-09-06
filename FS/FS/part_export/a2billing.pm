package FS::part_export::a2billing;

use strict;
use vars qw(@ISA @EXPORT_OK $DEBUG %info %options);
use Exporter;
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs str2time_sql );
use FS::part_export;
use FS::svc_acct;
use FS::svc_phone;
use Locale::Country qw(country_code2code);
use Date::Format qw(time2str);
use Carp qw( cluck );

@ISA = qw(FS::part_export);

$DEBUG = 0;

tie %options, 'Tie::IxHash',
  'datasrc'     => { label=>'DBI data source ' },
  'username'    => { label=>'Database username' },
  'password'    => { label=>'Database password' },
  'didgroup'    => { label=>'DID group ID', default=>1 },
  'credit'      => { label=>'Default credit limit' },
  'billtype'    => {label=>'Billing type',
                    type => 'select',
                    options => ['monthly', 'weekly']
                  },
  'debug'       => { label=>'Enable debugging', type=>'checkbox' }
;

my $notes = <<'END';
<p>Real-time export to the backend database of an <a
href="http://www.asterisk2billing.org">Asterisk2Billing</a> billing server.
This is both a svc_acct and a svc_phone export, and needs to be attached 
to both a svc_acct and svc_phone definition within the same package.</p>
<ul>
<li>When you set up this export, it will create 'svcnum' fields in the 
cc_card and cc_did tables in the A2Billing database to store the 
service numbers of svc_acct and svc_phone records.  The database username 
must have ALTER TABLE privileges.</li>
<li><i>DBI data source</i> should look like<br>
<b>dbi:mysql:host=</b><i>hostname</i><b>;database=</b><i>dbname</i>
</li>
END

%info = (
  'svc'      => ['svc_acct', 'svc_phone'],
  'desc'     => 'Export to Asterisk2Billing database',
  'options'  => \%options,
  'nodomain' => 'Y',
  'no_machine' => 1,
  'notes'    => $notes
);

sub dbh {
  my $self = shift;
  $self->{dbh} ||= DBI->connect(
                      $self->option('datasrc'),
                      $self->option('username'),
                      $self->option('password')
                      ) or die $DBI::errstr;

  $self->{dbh}->trace(1, '%%%FREESIDE_LOG%%%/a2b_exportlog.'.$self->exportnum)
    if $DEBUG;

  $self->{dbh};
}

# hook insert/replace, because we need to make some changes to the
# database when the export is created
sub insert {
  my $self = shift;
  my $error = $self->SUPER::insert(@_);
  return $error if $error;
  if ( $self->option('datasrc') ) {
    my $error;
    foreach (qw(cc_card cc_did)) {
      $self->dbh->do("ALTER TABLE $_ ADD COLUMN svcnum int")
        or $error = $self->dbh->errstr;
      $error = '' if $error =~ /Duplicate column name/; # harmless
      return "Error preparing a2billing database: $error\n" if $error;
    }
  }
  '';
}

sub replace {
  my $new = shift;
  my $old = shift || $new->replace_old;
  my $old_datasrc = $old->option('datasrc');
  my $error = $new->SUPER::replace($old, @_);
  return $error if $error;

  if ($new->option('datasrc') and $new->option('datasrc') ne $old_datasrc) {
    my $dbh = $new->a2b_connect;
    my $error;
    foreach (qw(cc_card cc_did)) {
      $new->dbh->do("ALTER TABLE $_ ADD COLUMN svcnum int")
        or $error = $new->dbh->errstr;
      $error = '' if $error =~ /Duplicate column name/; # harmless
      return "Error preparing a2billing database: $error\n" if $error;
    }
  }
  '';
}

sub export_insert {
  my $self = shift;
  my $svc = shift;
  my $cust_pkg = $svc->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;
  my $location = $cust_pkg->cust_location;
  my $part_pkg = $cust_pkg->part_pkg;

  my $error;
  $DEBUG ||= $self->option('debug');

  # 3-letter UN country code
  my $country3 = uc(country_code2code($location->country, 'alpha2' => 'alpha3'));
  
  my $dbh = $self->a2b_connect;

  if ( $svc->isa('FS::svc_acct') ) {
    # export to cc_card (customer identity) and cc_sip_buddies (SIP extension)

    my $username = $svc->username;

    my %cc_card = (
      svcnum    => $svc->svcnum,
      username  => $username,
      useralias => $username,
      uipass    => $svc->_password,
      credit    => $self->option('credit') || 0,
      tariff    => $part_pkg->option('a2billing_tariff'),
      status    => 1,
      lastname  => $cust_main->last, # $svc->finger?
      firstname => $cust_main->first,
      address   => $location->address1 .
                  ($location->address2 ? ', '.$location->address2 : ''),
      city      => $location->city,
      state     => $location->state,
      country   => $country3,
      zipcode   => $location->zip,
      typepaid  => $part_pkg->option('a2billing_type'),
      sip_buddy => 1,
      company_name => $cust_main->company,
      activated => 't',
    );
    warn "creating A2B cc_card record for $username\n" if $DEBUG;
    $error = $self->a2b_insert_or_replace('cc_card', 'svcnum', \%cc_card);
    return "Error creating A2Billing customer identity: $error" if $error;
    
    my $fullcontact = '';
    if ( $svc->ip_addr ) {
      $fullcontact = "sip:$username\@".$svc->ip_addr;
    }

    my $cc_card_id = $self->a2b_find('cc_card', 'svcnum', $svc->svcnum);
    # these are the fields we know about; some of them might need to be 
    # export options eventually, and there are a lot more fields in the table
    my %cc_sip_buddy = (
      id_cc_card      => $cc_card_id,
      name            => $username,
      accountcode     => $username,
      regexten        => $username,
      amaflags        => 'billing',
      context         => 'a2billing',
      host            => 'dynamic',
      port            => 5060,
      secret          => $svc->_password,
      username        => $username,
      allow           => 'ulaw,alaw,gsm,g729',
      ipaddr          => ($svc->slipip || ''),
      fullcontact     => $fullcontact,
    );
    warn "creating A2B cc_sip_buddies record for $username\n" if $DEBUG;
    $error = $self->a2b_insert_or_replace('cc_sip_buddies', 'id_cc_card',
                                          \%cc_sip_buddy);
    return "Error creating A2Billing SIP extension: $error" if $error;

    # then, if there are any DIDs on the package, set them up
    foreach ( $self->_linked_svcs($svc, 'svc_phone') ) {
      warn "triggering export of svc_phone #".$_->svcnum."\n" if $DEBUG;
      $error = $self->export_insert($_->svc_x);
      return $error if $error;
    }
    return '';

  } elsif ( $svc->isa('FS::svc_phone') ) {
    # find the linked svc_acct
    my $svc_acct;
    foreach ($self->_linked_svcs($svc, 'svc_acct')) {
      $svc_acct = $_->svc_x;
      last;
    }
    if ( !$svc_acct ) {
      # it hasn't been created yet, so just exit.
      # this service will be exported later.
      warn "no linked svc_acct; deferring phone number export\n" if $DEBUG;
      return '';
    }
    # find the card and sip_buddies records
    my $cc_card_id = $self->a2b_find('cc_card', 'svcnum', $svc_acct->svcnum);
    my $cc_sip_buddies_id = $self->a2b_find('cc_sip_buddies', 'id_cc_card', $cc_card_id);
    if (!$cc_card_id or !$cc_sip_buddies_id) {
      warn "When exporting svc_phone #".$svc->svcnum.", svc_acct #".$svc_acct->svcnum." was not found in A2Billing.\n";
      if ( $FS::svc_Common::noexport_hack ) {
        # recursion protection
        return "During export of linked DID#".$svc->phonenum.", svc_acct #".$svc_acct->svcnum." was not found in A2Billing.";
      }
      return $svc_acct->export_insert; # which will call back to here when 
                                       # it's done
    }

    # Create the DID.
    my $cc_country_id = $self->a2b_find('cc_country', 'countrycode', $country3);
    my %cc_did = (
      svcnum          => $svc->svcnum,
      id_cc_didgroup  => $self->option('didgroup'),
      id_cc_country   => $cc_country_id,
      iduser          => $cc_card_id,
      did             => $svc->phonenum,
      billingtype     => ($self->option('billtype') eq 'weekly' ? 1 : 0),
      activated       => 1,
    );

    # use 'did' as the key here so that if the DID already exists, we 
    # link it to this customer.
    $error = $self->a2b_insert_or_replace('cc_did', 'did', \%cc_did);
    return "Error creating A2Billing DID record: $error" if $error;

    my $cc_did_id = $self->a2b_find('cc_did', 'svcnum', $svc->svcnum);
    
    my $destination = 'SIP/' . $svc->phonenum . '@' . $svc_acct->username;
    my %cc_did_destination = (
      destination     => $destination,
      priority        => 1,
      id_cc_card      => $cc_card_id,
      id_cc_did       => $cc_did_id,
    );

    # and if there's already a destination, change it to point to
    # this customer's SIP extension
    $error = $self->a2b_insert_or_replace('cc_did_destination', 'id_cc_did',
                                          \%cc_did_destination);
    return "Error linking A2Billing DID record to customer: $error" if $error;

    my %cc_did_use = (
      id_cc_card      => $cc_card_id,
      id_did          => $cc_did_id,
      activated       => 1,
      month_payed     => 1, # it's the default in the A2Billing code, I think
    );
    # and change the in-use record, too
    my $id_use = $self->a2b_find('cc_did_use',
      id_did          => $cc_did_id,
      activated       => 1,
    );
    if ( $id_use ) {
      $error = $self->a2b_insert_or_replace('cc_did_use', 'id',
        { id          => $id_use,
          releasedate => time2str('%Y-%m-%d %H:%M:%S', time),
          activated   => 0
        }
      );
      return "Error closing existing A2Billing DID assignment record: $error"
        if $error;

      # and do an update instead of an insert
      $cc_did_use{id} = $id_use;
    }

    $error = $self->a2b_insert_or_replace('cc_did_use', 'id', \%cc_did_use);
    return "Error creating A2Billing DID use record: $error" if $error;

  } # if $svc->isa(...)
  '';
}

sub export_delete {
  my $self = shift;
  my $svc = shift;

  my $error;
  $DEBUG ||= $self->option('debug');

  if ( $svc->isa('FS::svc_acct') ) {

    # first remove the DID links
    foreach ($self->_linked_svcs($svc, 'svc_phone')) {
      warn "triggering export of svc_phone #".$_->svcnum."\n" if $DEBUG;
      $error = $self->export_delete($_->svc_x);
      return $error if $error;
    }

    # a2billing never deletes a card, just sets status = 0.
    # though we also need to remove the svcnum, since that svcnum is no 
    # longer valid.
    my $cc_card_id = $self->a2b_find('cc_card', 'svcnum', $svc->svcnum);
    if (!$cc_card_id) {
      warn "tried to remove svc_acct #".$svc->svcnum." from A2Billing, but couldn't find it.\n";
      # which is not really a problem.
      return '';
    }
    warn "deactivating A2B cc_card record #$cc_card_id\n" if $DEBUG;
    $error = $self->a2b_insert_or_replace('cc_card', 'id', {
        id        => $cc_card_id,
        status    => 0,
        activated => 0,
        svcnum    => 0,
    });
    return $error if $error;

  } elsif ( $svc->isa('FS::svc_phone') ) {

    my $cc_did_id = $self->a2b_find('cc_did', 'svcnum', $svc->svcnum);
    if ( $cc_did_id ) {
      warn "deactivating DID ".$svc->phonenum."\n" if $DEBUG;
      $error = $self->a2b_insert_or_replace('cc_did', 'id',
        { id        => $cc_did_id,
          activated => 0,
          iduser    => 0,
          svcnum    => 0,
        }
      );
      return $error if $error;
    } else {
      warn "tried to remove svc_phone #".$svc->svcnum." from A2Billing, but couldn't find it.\n";
      return '';
    }

    my $cc_did_destination_id = $self->a2b_find('cc_did_destination',
      'id_cc_did', $cc_did_id,
      'activated', 1
    );
    if ( $cc_did_destination_id ) {
      warn "unlinking DID ".$svc->phonenum." from customer\n" if $DEBUG;
      $error = $self->a2b_delete('cc_did_destination', $cc_did_destination_id);
      return $error if $error;
    } else {
      warn "no cc_did_destination found for cc_did #$cc_did_id\n";
    }
    
    my $cc_did_use_id = $self->a2b_find('cc_did_use',
      'id_did', $cc_did_id,
      'activated', 1
    );
    if ( $cc_did_use_id ) {
      warn "closing DID assignment\n" if $DEBUG;
      $error = $self->a2b_insert_or_replace('cc_did_use', 'id',
        { id          => $cc_did_use_id,
          releasedate => time2str('%Y-%m-%d %H:%M:%S', time),
          activated   => 0
        }
      );
      return "Error closing existing A2Billing DID assignment record: $error"
        if $error;
    } else {
      warn "no cc_did_use found for cc_did #$cc_did_id\n";
    }

  }
  '';
}

sub export_replace {
  my $self = shift;
  my $new = shift;
  my $old = shift || $self->replace_old;

  my $error;
  $DEBUG ||= $self->option('debug');

  if ( $new->isa('FS::svc_acct') ) {

    my $cc_card_id = $self->a2b_find('cc_card', 'svcnum', $new->svcnum);
    if ( $cc_card_id and $new->username ne $old->username ) {
      # If the username is changing and any DIDs are provisioned, we need to 
      # change their destinations.  To do this, we unlink them.  This will 
      # close their did_use records, delete their cc_did_destinations, and 
      # set their cc_dids to inactive.
      foreach ($self->_linked_svcs($new, 'svc_phone')) {
        warn "triggering export of svc_phone #".$_->svcnum."\n" if $DEBUG;
        $error = $self->export_delete($_->svc_x);
        return $error if $error;
      }
    }

    # export_insert will replace the record with the same svcnum, if there 
    # is one, and then re-export all existing DIDs (which is convenient since
    # we just unlinked them).
    $error = $self->export_insert($new);
    return $error if $error;

  } elsif ( $new->isa('FS::svc_phone') ) {

    # if the phone number has changed, need to create a new DID.
    if ( $new->phonenum ne $old->phonenum ) {
      # deactivate/unlink/close the old DID
      # and create/link the new one
      $error = $self->export_delete($old)
            || $self->export_insert($new);
      return $error if $error;
    }
    # otherwise we don't care
  }

  '';
}

sub export_suspend {
  my $self = shift;
  my $svc = shift;

  my $error;
  $DEBUG ||= $self->option('debug');

  if ( $svc->isa('FS::svc_acct') ) {
    $error = $self->a2b_insert_or_replace('cc_card', 'svcnum',
      { svcnum    => $svc->svcnum,
        status    => 6, # "SUSPENDED FOR UNDERPAYMENT"
        activated => 0, # still used in some places, grrr
      }
    );
  } elsif ( $svc->isa('FS::svc_phone') ) {
    # deactivate the DID
    $error = $self->a2b_insert_or_replace('cc_did', 'svcnum',
      { svcnum    => $svc->svcnum,
        activated => 0,
      }
    );
  }
  $error || '';
}

sub export_unsuspend {
  my $self = shift;
  my $svc = shift;

  my $error;
  $DEBUG ||= $self->option('debug');

  if ( $svc->isa('FS::svc_acct') ) {
    $error = $self->a2b_insert_or_replace('cc_card', 'svcnum',
      { svcnum    => $svc->svcnum,
        status    => 0, #"ACTIVE"
        activated => 1,
      }
    );
  } elsif ( $svc->isa('FS::svc_phone') ) {
    $error = $self->a2b_insert_or_replace('cc_did', 'svcnum',
      { svcnum    => $svc->svcnum,
        activated => 1,
      }
    );
  }
  $error || '';
}

=item a2b_insert_or_replace TABLE KEY HASHREF

Create a record in TABLE with the values in HASHREF.  If there's already one 
that matches on the KEY field, update the existing record instead of creating
a new one.  Pass an empty KEY to just insert the record without checking.

=cut

sub a2b_insert_or_replace {
  my $self = shift;
  my $table = shift;
  my $key = shift;
  my $hashref = shift;

  if ( $key ) {
    my $id = $self->a2b_find($table, $key, $hashref->{$key});
    if ( $id ) {
      my $sql = "UPDATE $table SET " .
                join(', ', map { "$_ = ?" } keys(%$hashref)) .
                " WHERE id = ?";
      $self->dbh->do($sql, {}, values(%$hashref), $id)
        or return $self->dbh->errstr;
      return '';
    }
  }
  # no key, or no existing record
  my $sql = "INSERT INTO $table (".  join(', ', keys(%$hashref)) . ")" .
            " VALUES (" . join(', ', map { '?' } keys(%$hashref)) . ")";
  $self->dbh->do($sql, {}, values(%$hashref))
    or return $self->dbh->errstr;
  return '';
}

=item a2b_delete TABLE ID

Remove the record with id ID from TABLE.

=cut

sub a2b_delete {
  my $self = shift;
  my ($table, $id) = @_;
  my $sql = "DELETE FROM $table WHERE id = ?";
  $self->dbh->do($sql, {}, $id)
    or return $self->dbh->errstr;
  return '';
}

=item a2b_find TABLE KEY VALUE [ KEY VALUE ... ]

Search TABLE for a row where KEY equals VALUE, and return its "id" field.

=cut

sub a2b_find {
  my $self = shift;
  my ($table, %params) = @_;
  my $sql = "SELECT id FROM $table WHERE " .
    join(' AND ', map { "$_ = ?" } keys(%params));
  my ($id) = $self->dbh->selectrow_array($sql, {}, values(%params));
  die $self->dbh->errstr if $self->dbh->errstr;
  $id || '';
}

# find services on the same package that are exportable with this export
# and are of a specified svcdb
#
# just to avoid repeating myself
sub _linked_svcs {
  my ($self, $svc, $svcdb) = @_;
  # index the svcparts that belong to the a2billing export
  my $export_svcparts = $self->{export_svcparts} ||= 
    { map { $_->svcpart => $_->part_svc->svcdb }
      $self->export_svc
    };

  my $pkgnum = $svc->cust_svc->pkgnum;
  my @svcs = qsearch('cust_svc', { pkgnum => $pkgnum });
  grep { $export_svcparts->{$_->svcpart} eq $svcdb } @svcs;
}

1;
