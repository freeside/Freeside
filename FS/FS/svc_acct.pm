package FS::svc_acct;

use strict;
use vars qw( @ISA $noexport_hack $conf
             $dir_prefix @shells $usernamemin
             $usernamemax $passwordmin $passwordmax
             $username_ampersand $username_letter $username_letterfirst
             $username_noperiod $username_nounderscore $username_nodash
             $username_uppercase
             $mydomain
             $welcome_template $welcome_from $welcome_subject $welcome_mimetype
             $smtpmachine
             $dirhash
             @saltset @pw_set );
use Carp;
use Fcntl qw(:flock);
use FS::UID qw( datasrc );
use FS::Conf;
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::svc_Common;
use Net::SSH;
use FS::cust_svc;
use FS::part_svc;
use FS::svc_acct_pop;
use FS::svc_acct_sm;
use FS::cust_main_invoice;
use FS::svc_domain;
use FS::raddb;
use FS::queue;
use FS::radius_usergroup;
use FS::export_svc;
use FS::part_export;
use FS::Msgcat qw(gettext);

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_acct'} = sub { 
  $conf = new FS::Conf;
  $dir_prefix = $conf->config('home');
  @shells = $conf->config('shells');
  $usernamemin = $conf->config('usernamemin') || 2;
  $usernamemax = $conf->config('usernamemax');
  $passwordmin = $conf->config('passwordmin') || 6;
  $passwordmax = $conf->config('passwordmax') || 8;
  $username_letter = $conf->exists('username-letter');
  $username_letterfirst = $conf->exists('username-letterfirst');
  $username_noperiod = $conf->exists('username-noperiod');
  $username_nounderscore = $conf->exists('username-nounderscore');
  $username_nodash = $conf->exists('username-nodash');
  $username_uppercase = $conf->exists('username-uppercase');
  $username_ampersand = $conf->exists('username-ampersand');
  $mydomain = $conf->config('domain');
  $dirhash = $conf->config('dirhash') || 0;
  if ( $conf->exists('welcome_email') ) {
    $welcome_template = new Text::Template (
      TYPE   => 'ARRAY',
      SOURCE => [ map "$_\n", $conf->config('welcome_email') ]
    ) or warn "can't create welcome email template: $Text::Template::ERROR";
    $welcome_from = $conf->config('welcome_email-from'); # || 'your-isp-is-dum'
    $welcome_subject = $conf->config('welcome_email-subject') || 'Welcome';
    $welcome_mimetype = $conf->config('welcome_email-mimetype') || 'text/plain';
  } else {
    $welcome_template = '';
  }
  $smtpmachine = $conf->config('smtpmachine');
};

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );
@pw_set = ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '!', '.', ',' );

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  if ( $hashref->{'svc_acct_svcnum'} ) {
    $self->{'_domsvc'} = FS::svc_domain->new( {
      'svcnum'   => $hashref->{'domsvc'},
      'domain'   => $hashref->{'svc_acct_domain'},
      'catchall' => $hashref->{'svc_acct_catchall'},
    } );
  }
}

=head1 NAME

FS::svc_acct - Object methods for svc_acct records

=head1 SYNOPSIS

  use FS::svc_acct;

  $record = new FS::svc_acct \%hash;
  $record = new FS::svc_acct { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

  %hash = $record->radius;

  %hash = $record->radius_reply;

  %hash = $record->radius_check;

  $domain = $record->domain;

  $svc_domain = $record->svc_domain;

  $email = $record->email;

  $seconds_since = $record->seconds_since($timestamp);

=head1 DESCRIPTION

An FS::svc_acct object represents an account.  FS::svc_acct inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatcially for new accounts)

=item username

=item _password - generated if blank

=item sec_phrase - security phrase

=item popnum - Point of presence (see L<FS::svc_acct_pop>)

=item uid

=item gid

=item finger - GECOS

=item dir - set automatically if blank (and uid is not)

=item shell

=item quota - (unimplementd)

=item slipip - IP address

=item seconds - 

=item domsvc - svcnum from svc_domain

=item radius_I<Radius_Attribute> - I<Radius-Attribute>

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new account.  To add the account to the database, see L<"insert">.

=cut

sub table { 'svc_acct'; }

=item insert

Adds this account to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

The additional field I<usergroup> can optionally be defined; if so it should
contain an arrayref of group names.  See L<FS::radius_usergroup>.  (used in
sqlradius export only)

(TODOC: L<FS::queue> and L<freeside-queued>)

(TODOC: new exports! $noexport_hack)

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  return $error if $error;

  #no, duplicate checking just got a whole lot more complicated
  #(perhaps keep this check with a config option to turn on?)

  #return gettext('username_in_use'). ": ". $self->username
  #  if qsearchs( 'svc_acct', { 'username' => $self->username,
  #                             'domsvc'   => $self->domsvc,
  #                           } );

  if ( $self->svcnum ) {
    my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$self->svcnum});
    unless ( $cust_svc ) {
      $dbh->rollback if $oldAutoCommit;
      return "no cust_svc record found for svcnum ". $self->svcnum;
    }
    $self->pkgnum($cust_svc->pkgnum);
    $self->svcpart($cust_svc->svcpart);
  }

  #new duplicate username checking

  my $part_svc = qsearchs('part_svc', { 'svcpart' => $self->svcpart } );
  unless ( $part_svc ) {
    $dbh->rollback if $oldAutoCommit;
    return 'unknown svcpart '. $self->svcpart;
  }

  my @dup_user = qsearch( 'svc_acct', { 'username' => $self->username } );
  my @dup_userdomain = qsearch( 'svc_acct', { 'username' => $self->username,
                                              'domsvc'   => $self->domsvc } );
  my @dup_uid;
  if ( $part_svc->part_svc_column('uid')->columnflag ne 'F'
       && $self->username !~ /^(toor|(hyla)?fax)$/          ) {
    @dup_uid = qsearch( 'svc_acct', { 'uid' => $self->uid } );
  } else {
    @dup_uid = ();
  }

  if ( @dup_user || @dup_userdomain || @dup_uid ) {
    my $exports = FS::part_export::export_info('svc_acct');
    my %conflict_user_svcpart;
    my %conflict_userdomain_svcpart = ( $self->svcpart => 'SELF', );

    foreach my $part_export ( $part_svc->part_export ) {

      #this will catch to the same exact export
      my @svcparts = map { $_->svcpart }
        qsearch('export_svc', { 'exportnum' => $part_export->exportnum });

      #this will catch to exports w/same exporthost+type ???
      #my @other_part_export = qsearch('part_export', {
      #  'machine'    => $part_export->machine,
      #  'exporttype' => $part_export->exporttype,
      #} );
      #foreach my $other_part_export ( @other_part_export ) {
      #  push @svcparts, map { $_->svcpart }
      #    qsearch('export_svc', { 'exportnum' => $part_export->exportnum });
      #}

      my $nodomain = $exports->{$part_export->exporttype}{'nodomain'};
      if ( $nodomain =~ /^Y/i ) {
        $conflict_user_svcpart{$_} = $part_export->exportnum
          foreach @svcparts;
      } else {
        $conflict_userdomain_svcpart{$_} = $part_export->exportnum
          foreach @svcparts;
      }
    }

    foreach my $dup_user ( @dup_user ) {
      my $dup_svcpart = $dup_user->cust_svc->svcpart;
      if ( exists($conflict_user_svcpart{$dup_svcpart}) ) {
        $dbh->rollback if $oldAutoCommit;
        return "duplicate username: conflicts with svcnum ". $dup_user->svcnum.
               " via exportnum ". $conflict_user_svcpart{$dup_svcpart};
      }
    }

    foreach my $dup_userdomain ( @dup_userdomain ) {
      my $dup_svcpart = $dup_userdomain->cust_svc->svcpart;
      if ( exists($conflict_userdomain_svcpart{$dup_svcpart}) ) {
        $dbh->rollback if $oldAutoCommit;
        return "duplicate username\@domain: conflicts with svcnum ".
               $dup_userdomain->svcnum. " via exportnum ".
               $conflict_userdomain_svcpart{$dup_svcpart};
      }
    }

    foreach my $dup_uid ( @dup_uid ) {
      my $dup_svcpart = $dup_uid->cust_svc->svcpart;
      if ( exists($conflict_user_svcpart{$dup_svcpart})
           || exists($conflict_userdomain_svcpart{$dup_svcpart}) ) {
        $dbh->rollback if $oldAutoCommit;
        return "duplicate uid: conflicts with svcnum". $dup_uid->svcnum.
               "via exportnum ". $conflict_user_svcpart{$dup_svcpart}
                                 || $conflict_userdomain_svcpart{$dup_svcpart};
      }
    }

  }

  #see?  i told you it was more complicated

  my @jobnums;
  $error = $self->SUPER::insert(\@jobnums);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->usergroup ) {
    foreach my $groupname ( @{$self->usergroup} ) {
      my $radius_usergroup = new FS::radius_usergroup ( {
        svcnum    => $self->svcnum,
        groupname => $groupname,
      } );
      my $error = $radius_usergroup->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  #false laziness with sub replace (and cust_main)
  my $queue = new FS::queue {
    'svcnum' => $self->svcnum,
    'job'    => 'FS::svc_acct::append_fuzzyfiles'
  };
  $error = $queue->insert($self->username);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "queueing job (transaction rolled back): $error";
  }

  my $cust_pkg = $self->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  my $cust_pkg = $self->cust_svc->cust_pkg;

  if ( $conf->exists('emailinvoiceauto') ) {
    my @invoicing_list = $cust_main->invoicing_list;
    push @invoicing_list, $self->email;
    $cust_main->invoicing_list(@invoicing_list);
  }

  #welcome email
  my $to = '';
  if ( $welcome_template && $cust_pkg ) {
    my $to = join(', ', grep { $_ ne 'POST' } $cust_main->invoicing_list );
    if ( $to ) {
      my $wqueue = new FS::queue {
        'svcnum' => $self->svcnum,
        'job'    => 'FS::svc_acct::send_email'
      };
      warn "attempting to queue email to $to";
      my $error = $wqueue->insert(
        'to'       => $to,
        'from'     => $welcome_from,
        'subject'  => $welcome_subject,
        'mimetype' => $welcome_mimetype,
        'body'     => $welcome_template->fill_in( HASH => {
                        'username' => $self->username,
                        'password' => $self->_password,
                        'first'    => $cust_main->first,
                        'last'     => $cust_main->getfield('last'),
                        'pkg'      => $cust_pkg->part_pkg->pkg,
                      } ),
      );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "queuing welcome email: $error";
      }
  
      foreach my $jobnum ( @jobnums ) {
        my $error = $wqueue->depend_insert($jobnum);
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "queuing welcome email job dependancy: $error";
        }
      }

    }
  
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item delete

Deletes this account from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

(TODOC: new exports! $noexport_hack)

=cut

sub delete {
  my $self = shift;

  if ( defined( $FS::Record::dbdef->table('svc_acct_sm') ) ) {
    return "Can't delete an account which has (svc_acct_sm) mail aliases!"
      if $self->uid && qsearch( 'svc_acct_sm', { 'domuid' => $self->uid } );
  }

  return "Can't delete an account which is a (svc_forward) source!"
    if qsearch( 'svc_forward', { 'srcsvc' => $self->svcnum } );

  return "Can't delete an account which is a (svc_forward) destination!"
    if qsearch( 'svc_forward', { 'dstsvc' => $self->svcnum } );

  return "Can't delete an account with (svc_www) web service!"
    if qsearch( 'svc_www', { 'usersvc' => $self->usersvc } );

  # what about records in session ? (they should refer to history table)

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_main_invoice (
    qsearch( 'cust_main_invoice', { 'dest' => $self->svcnum } )
  ) {
    unless ( defined($cust_main_invoice) ) {
      warn "WARNING: something's wrong with qsearch";
      next;
    }
    my %hash = $cust_main_invoice->hash;
    $hash{'dest'} = $self->email;
    my $new = new FS::cust_main_invoice \%hash;
    my $error = $new->replace($cust_main_invoice);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $svc_domain (
    qsearch( 'svc_domain', { 'catchall' => $self->svcnum } )
  ) {
    my %hash = new FS::svc_domain->hash;
    $hash{'catchall'} = '';
    my $new = new FS::svc_domain \%hash;
    my $error = $new->replace($svc_domain);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $radius_usergroup (
    qsearch('radius_usergroup', { 'svcnum' => $self->svcnum } )
  ) {
    my $error = $radius_usergroup->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

The additional field I<usergroup> can optionally be defined; if so it should
contain an arrayref of group names.  See L<FS::radius_usergroup>.  (used in
sqlradius export only)

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  return "Username in use"
    if $old->username ne $new->username &&
      qsearchs( 'svc_acct', { 'username' => $new->username,
                               'domsvc'   => $new->domsvc,
                             } );
  {
    #no warnings 'numeric';  #alas, a 5.006-ism
    local($^W) = 0;
    return "Can't change uid!" if $old->uid != $new->uid;
  }

  #change homdir when we change username
  $new->setfield('dir', '') if $old->username ne $new->username;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $old->usergroup( [ $old->radius_groups ] );
  if ( $new->usergroup ) {
    #(sorta) false laziness with FS::part_export::sqlradius::_export_replace
    my @newgroups = @{$new->usergroup};
    foreach my $oldgroup ( @{$old->usergroup} ) {
      if ( grep { $oldgroup eq $_ } @newgroups ) {
        @newgroups = grep { $oldgroup ne $_ } @newgroups;
        next;
      }
      my $radius_usergroup = qsearchs('radius_usergroup', {
        svcnum    => $old->svcnum,
        groupname => $oldgroup,
      } );
      my $error = $radius_usergroup->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error deleting radius_usergroup $oldgroup: $error";
      }
    }

    foreach my $newgroup ( @newgroups ) {
      my $radius_usergroup = new FS::radius_usergroup ( {
        svcnum    => $new->svcnum,
        groupname => $newgroup,
      } );
      my $error = $radius_usergroup->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error adding radius_usergroup $newgroup: $error";
      }
    }

  }

  $error = $new->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error if $error;
  }

  #false laziness with sub insert (and cust_main)
  my $queue = new FS::queue {
    'svcnum' => $new->svcnum,
    'job'    => 'FS::svc_acct::append_fuzzyfiles'
  };
  $error = $queue->insert($new->username);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "queueing job (transaction rolled back): $error";
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item suspend

Suspends this account by prefixing *SUSPENDED* to the password.  If there is an
error, returns the error, otherwise returns false.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub suspend {
  my $self = shift;
  my %hash = $self->hash;
  unless ( $hash{_password} =~ /^\*SUSPENDED\* /
           || $hash{_password} eq '*'
         ) {
    $hash{_password} = '*SUSPENDED* '.$hash{_password};
    my $new = new FS::svc_acct ( \%hash );
    my $error = $new->replace($self);
    return $error if $error;
  }

  $self->SUPER::suspend;
}

=item unsuspend

Unsuspends this account by removing *SUSPENDED* from the password.  If there is
an error, returns the error, otherwise returns false.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub unsuspend {
  my $self = shift;
  my %hash = $self->hash;
  if ( $hash{_password} =~ /^\*SUSPENDED\* (.*)$/ ) {
    $hash{_password} = $1;
    my $new = new FS::svc_acct ( \%hash );
    my $error = $new->replace($self);
    return $error if $error;
  }

  $self->SUPER::unsuspend;
}

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;

  my($recref) = $self->hashref;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  if ( $part_svc->part_svc_column('usergroup')->columnflag eq "F" ) {
    $self->usergroup(
      [ split(',', $part_svc->part_svc_column('usergroup')->columnvalue) ] );
  }

  my $error = $self->ut_numbern('svcnum')
              || $self->ut_number('domsvc')
              || $self->ut_textn('sec_phrase')
  ;
  return $error if $error;

  my $ulen = $usernamemax || $self->dbdef_table->column('username')->length;
  if ( $username_uppercase ) {
    $recref->{username} =~ /^([a-z0-9_\-\.\&]{$usernamemin,$ulen})$/i
      or return gettext('illegal_username'). " ($usernamemin-$ulen): ". $recref->{username};
    $recref->{username} = $1;
  } else {
    $recref->{username} =~ /^([a-z0-9_\-\.\&]{$usernamemin,$ulen})$/
      or return gettext('illegal_username'). " ($usernamemin-$ulen): ". $recref->{username};
    $recref->{username} = $1;
  }

  if ( $username_letterfirst ) {
    $recref->{username} =~ /^[a-z]/ or return gettext('illegal_username');
  } elsif ( $username_letter ) {
    $recref->{username} =~ /[a-z]/ or return gettext('illegal_username');
  }
  if ( $username_noperiod ) {
    $recref->{username} =~ /\./ and return gettext('illegal_username');
  }
  if ( $username_nounderscore ) {
    $recref->{username} =~ /_/ and return gettext('illegal_username');
  }
  if ( $username_nodash ) {
    $recref->{username} =~ /\-/ and return gettext('illegal_username');
  }
  unless ( $username_ampersand ) {
    $recref->{username} =~ /\&/ and return gettext('illegal_username');
  }

  $recref->{popnum} =~ /^(\d*)$/ or return "Illegal popnum: ".$recref->{popnum};
  $recref->{popnum} = $1;
  return "Unknown popnum" unless
    ! $recref->{popnum} ||
    qsearchs('svc_acct_pop',{'popnum'=> $recref->{popnum} } );

  unless ( $part_svc->part_svc_column('uid')->columnflag eq 'F' ) {

    $recref->{uid} =~ /^(\d*)$/ or return "Illegal uid";
    $recref->{uid} = $1 eq '' ? $self->unique('uid') : $1;

    $recref->{gid} =~ /^(\d*)$/ or return "Illegal gid";
    $recref->{gid} = $1 eq '' ? $recref->{uid} : $1;
    #not all systems use gid=uid
    #you can set a fixed gid in part_svc

    return "Only root can have uid 0"
      if $recref->{uid} == 0
         && $recref->{username} ne 'root'
         && $recref->{username} ne 'toor';


    $recref->{dir} =~ /^([\/\w\-\.\&]*)$/
      or return "Illegal directory: ". $recref->{dir};
    $recref->{dir} = $1;
    return "Illegal directory"
      if $recref->{dir} =~ /(^|\/)\.+(\/|$)/; #no .. component
    return "Illegal directory"
      if $recref->{dir} =~ /\&/ && ! $username_ampersand;
    unless ( $recref->{dir} ) {
      $recref->{dir} = $dir_prefix . '/';
      if ( $dirhash > 0 ) {
        for my $h ( 1 .. $dirhash ) {
          $recref->{dir} .= substr($recref->{username}, $h-1, 1). '/';
        }
      } elsif ( $dirhash < 0 ) {
        for my $h ( reverse $dirhash .. -1 ) {
          $recref->{dir} .= substr($recref->{username}, $h, 1). '/';
        }
      }
      $recref->{dir} .= $recref->{username};
    ;
    }

    unless ( $recref->{username} eq 'sync' ) {
      if ( grep $_ eq $recref->{shell}, @shells ) {
        $recref->{shell} = (grep $_ eq $recref->{shell}, @shells)[0];
      } else {
        return "Illegal shell \`". $self->shell. "\'; ".
               $conf->dir. "/shells contains: @shells";
      }
    } else {
      $recref->{shell} = '/bin/sync';
    }

  } else {
    $recref->{gid} ne '' ? 
      return "Can't have gid without uid" : ( $recref->{gid}='' );
    $recref->{dir} ne '' ? 
      return "Can't have directory without uid" : ( $recref->{dir}='' );
    $recref->{shell} ne '' ? 
      return "Can't have shell without uid" : ( $recref->{shell}='' );
  }

  #  $error = $self->ut_textn('finger');
  #  return $error if $error;
  $self->getfield('finger') =~
    /^([\w \t\!\@\#\$\%\&\(\)\-\+\;\'\"\,\.\?\/\*\<\>]*)$/
      or return "Illegal finger: ". $self->getfield('finger');
  $self->setfield('finger', $1);

  $recref->{quota} =~ /^(\d*)$/ or return "Illegal quota";
  $recref->{quota} = $1;

  unless ( $part_svc->part_svc_column('slipip')->columnflag eq 'F' ) {
    unless ( $recref->{slipip} eq '0e0' ) {
      $recref->{slipip} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
        or return "Illegal slipip". $self->slipip;
      $recref->{slipip} = $1;
    } else {
      $recref->{slipip} = '0e0';
    }

  }

  #arbitrary RADIUS stuff; allow ut_textn for now
  foreach ( grep /^radius_/, fields('svc_acct') ) {
    $self->ut_textn($_);
  }

  #generate a password if it is blank
  $recref->{_password} = join('',map($pw_set[ int(rand $#pw_set) ], (0..7) ) )
    unless ( $recref->{_password} );

  #if ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([^\t\n]{4,16})$/ ) {
  if ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([^\t\n]{$passwordmin,$passwordmax})$/ ) {
    $recref->{_password} = $1.$3;
    #uncomment this to encrypt password immediately upon entry, or run
    #bin/crypt_pw in cron to give new users a window during which their
    #password is available to techs, for faxing, etc.  (also be aware of 
    #radius issues!)
    #$recref->{password} = $1.
    #  crypt($3,$saltset[int(rand(64))].$saltset[int(rand(64))]
    #;
  } elsif ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([\w\.\/\$\;]{13,34})$/ ) {
    $recref->{_password} = $1.$3;
  } elsif ( $recref->{_password} eq '*' ) {
    $recref->{_password} = '*';
  } elsif ( $recref->{_password} eq '!!' ) {
    $recref->{_password} = '!!';
  } else {
    #return "Illegal password";
    return gettext('illegal_password'). " $passwordmin-$passwordmax ".
           FS::Msgcat::_gettext('illegal_password_characters').
           ": ". $recref->{_password};
  }

  ''; #no error
}

=item radius

Depriciated, use radius_reply instead.

=cut

sub radius {
  carp "FS::svc_acct::radius depriciated, use radius_reply";
  $_[0]->radius_reply;
}

=item radius_reply

Returns key/value pairs, suitable for assigning to a hash, for any RADIUS
reply attributes of this record.

Note that this is now the preferred method for reading RADIUS attributes - 
accessing the columns directly is discouraged, as the column names are
expected to change in the future.

=cut

sub radius_reply { 
  my $self = shift;
  my %reply =
    map {
      /^(radius_(.*))$/;
      my($column, $attrib) = ($1, $2);
      #$attrib =~ s/_/\-/g;
      ( $FS::raddb::attrib{lc($attrib)}, $self->getfield($column) );
    } grep { /^radius_/ && $self->getfield($_) } fields( $self->table );
  if ( $self->slipip && $self->slipip ne '0e0' ) {
    $reply{'Framed-IP-Address'} = $self->slipip;
  }
  %reply;
}

=item radius_check

Returns key/value pairs, suitable for assigning to a hash, for any RADIUS
check attributes of this record.

Note that this is now the preferred method for reading RADIUS attributes - 
accessing the columns directly is discouraged, as the column names are
expected to change in the future.

=cut

sub radius_check {
  my $self = shift;
  ( 'Password' => $self->_password,
    map {
      /^(rc_(.*))$/;
      my($column, $attrib) = ($1, $2);
      #$attrib =~ s/_/\-/g;
      ( $FS::raddb::attrib{lc($attrib)}, $self->getfield($column) );
    } grep { /^rc_/ && $self->getfield($_) } fields( $self->table )
  );
}

=item domain

Returns the domain associated with this account.

=cut

sub domain {
  my $self = shift;
  if ( $self->domsvc ) {
    #$self->svc_domain->domain;
    my $svc_domain = $self->svc_domain
      or die "no svc_domain.svcnum for svc_acct.domsvc ". $self->domsvc;
    $svc_domain->domain;
  } else {
    $mydomain or die "svc_acct.domsvc is null and no legacy domain config file";
  }
}

=item svc_domain

Returns the FS::svc_domain record for this account's domain (see
L<FS::svc_domain>).

=cut

sub svc_domain {
  my $self = shift;
  $self->{'_domsvc'}
    ? $self->{'_domsvc'}
    : qsearchs( 'svc_domain', { 'svcnum' => $self->domsvc } );
}

=item cust_svc

Returns the FS::cust_svc record for this account (see L<FS::cust_svc>).

sub cust_svc {
  my $self = shift;
  qsearchs( 'cust_svc', { 'svcnum' => $self->svcnum } );
}

=item email

Returns an email address associated with the account.

=cut

sub email {
  my $self = shift;
  $self->username. '@'. $self->domain;
}

=item seconds_since TIMESTAMP

Returns the number of seconds this account has been online since TIMESTAMP.
See L<FS::session>

TIMESTAMP is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=cut

#note: POD here, implementation in FS::cust_svc
sub seconds_since {
  my $self = shift;
  $self->cust_svc->seconds_since(@_);
}

=item radius_groups

Returns all RADIUS groups for this account (see L<FS::radius_usergroup>).

=cut

sub radius_groups {
  my $self = shift;
  if ( $self->usergroup ) {
    #when provisioning records, export callback runs in svc_Common.pm before
    #radius_usergroup records can be inserted...
    @{$self->usergroup};
  } else {
    map { $_->groupname }
      qsearch('radius_usergroup', { 'svcnum' => $self->svcnum } );
  }
}

=back

=head1 SUBROUTINES

=over 4

=item send_email

=cut

sub send_email {
  my %opt = @_;

  use Date::Format;
  use Mail::Internet 1.44;
  use Mail::Header;

  $opt{mimetype} ||= 'text/plain';
  $opt{mimetype} .= '; charset="iso-8859-1"' unless $opt{mimetype} =~ /charset/;

  $ENV{MAILADDRESS} = $opt{from};
  my $header = new Mail::Header ( [
    "From: $opt{from}",
    "To: $opt{to}",
    "Sender: $opt{from}",
    "Reply-To: $opt{from}",
    "Date: ". time2str("%a, %d %b %Y %X %z", time),
    "Subject: $opt{subject}",
    "Content-Type: $opt{mimetype}",
  ] );
  my $message = new Mail::Internet (
    'Header' => $header,
    'Body' => [ map "$_\n", split("\n", $opt{body}) ],
  );
  $!=0;
  $message->smtpsend( Host => $smtpmachine )
    or $message->smtpsend( Host => $smtpmachine, Debug => 1 )
      or die "can't send email to $opt{to} via $smtpmachine with SMTP: $!";
}

=item check_and_rebuild_fuzzyfiles

=cut

sub check_and_rebuild_fuzzyfiles {
  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
  -e "$dir/svc_acct.username"
    or &rebuild_fuzzyfiles;
}

=item rebuild_fuzzyfiles

=cut

sub rebuild_fuzzyfiles {

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;

  #username

  open(USERNAMELOCK,">>$dir/svc_acct.username")
    or die "can't open $dir/svc_acct.username: $!";
  flock(USERNAMELOCK,LOCK_EX)
    or die "can't lock $dir/svc_acct.username: $!";

  my @all_username = map $_->getfield('username'), qsearch('svc_acct', {});

  open (USERNAMECACHE,">$dir/svc_acct.username.tmp")
    or die "can't open $dir/svc_acct.username.tmp: $!";
  print USERNAMECACHE join("\n", @all_username), "\n";
  close USERNAMECACHE or die "can't close $dir/svc_acct.username.tmp: $!";

  rename "$dir/svc_acct.username.tmp", "$dir/svc_acct.username";
  close USERNAMELOCK;

}

=item all_username

=cut

sub all_username {
  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;
  open(USERNAMECACHE,"<$dir/svc_acct.username")
    or die "can't open $dir/svc_acct.username: $!";
  my @array = map { chomp; $_; } <USERNAMECACHE>;
  close USERNAMECACHE;
  \@array;
}

=item append_fuzzyfiles USERNAME

=cut

sub append_fuzzyfiles {
  my $username = shift;

  &check_and_rebuild_fuzzyfiles;

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "cache.". $FS::UID::datasrc;

  open(USERNAME,">>$dir/svc_acct.username")
    or die "can't open $dir/svc_acct.username: $!";
  flock(USERNAME,LOCK_EX)
    or die "can't lock $dir/svc_acct.username: $!";

  print USERNAME "$username\n";

  flock(USERNAME,LOCK_UN)
    or die "can't unlock $dir/svc_acct.username: $!";
  close USERNAME;

  1;
}



=item radius_usergroup_selector GROUPS_ARRAYREF [ SELECTNAME ]

=cut

sub radius_usergroup_selector {
  my $sel_groups = shift;
  my %sel_groups = map { $_=>1 } @$sel_groups;

  my $selectname = shift || 'radius_usergroup';

  my $dbh = dbh;
  my $sth = $dbh->prepare(
    'SELECT DISTINCT(groupname) FROM radius_usergroup ORDER BY groupname'
  ) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;
  my @all_groups = map { $_->[0] } @{$sth->fetchall_arrayref};

  my $html = <<END;
    <SCRIPT>
    function ${selectname}_doadd(object) {
      var myvalue = object.${selectname}_add.value;
      var optionName = new Option(myvalue,myvalue,false,true);
      var length = object.$selectname.length;
      object.$selectname.options[length] = optionName;
      object.${selectname}_add.value = "";
    }
    </SCRIPT>
    <SELECT MULTIPLE NAME="$selectname">
END

  foreach my $group ( @all_groups ) {
    $html .= '<OPTION';
    if ( $sel_groups{$group} ) {
      $html .= ' SELECTED';
      $sel_groups{$group} = 0;
    }
    $html .= ">$group</OPTION>\n";
  }
  foreach my $group ( grep { $sel_groups{$_} } keys %sel_groups ) {
    $html .= "<OPTION SELECTED>$group</OPTION>\n";
  };
  $html .= '</SELECT>';

  $html .= qq!<BR><INPUT TYPE="text" NAME="${selectname}_add">!.
           qq!<INPUT TYPE="button" VALUE="Add new group" onClick="${selectname}_doadd(this.form)">!;

  $html;
}

=back

=head1 BUGS

The $recref stuff in sub check should be cleaned up.

The suspend, unsuspend and cancel methods update the database, but not the
current object.  This is probably a bug as it's unexpected and
counterintuitive.

radius_usergroup_selector?  putting web ui components in here?  they should
probably live somewhere else...

=head1 SEE ALSO

L<FS::svc_Common>, edit/part_svc.cgi from an installed web interface,
export.html from the base documentation, L<FS::Record>, L<FS::Conf>,
L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, L<FS::queue>,
L<freeside-queued>), L<Net::SSH>, L<ssh>, L<FS::svc_acct_pop>,
schema.html from the base documentation.

=cut

1;

