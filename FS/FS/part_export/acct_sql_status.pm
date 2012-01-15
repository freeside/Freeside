package FS::part_export::acct_sql_status;
use base qw( FS::part_export::sql_Common );

use strict;
use warnings;
use vars qw( %info );

my $options = __PACKAGE__->sql_options;
delete $options->{$_} for qw( table schema static primary_key );

%info = (
  'svc'      => 'svc_acct',
  'options'  => $options,
  'nodomain' => '',
  'notes'    => <<END
Read mailbox status information (vacation and spam settings) from an SQL
database, tables "vacation" and "users" respectively.
END
);

sub rebless { shift; }

#don't want to inherit these from sql_Common
sub _export_insert    {}
sub _export_replace   {}
sub _export_delete    {}
sub _export_suspend   {}
sub _export_unsuspend {}

sub export_getstatus {
  my($self, $svc_acct, $htmlref, $hashref) = @_;

  my $dbh = DBI->connect( map $self->option($_), qw(datasrc username password) )
    or do { $hashref->{'error'} = "can't connect: ".  $DBI::errstr; return; };

  ###
  #vacation settings
  ###

  my $vsth = $dbh->prepare('SELECT * FROM vacation WHERE email = ?')
    or do { $hashref->{'error'} = "can't prepare: ". $dbh->errstr; return; };
  $vsth->execute( $svc_acct->email )
    or do { $hashref->{'error'} = "can't execute: ". $vsth->errstr; return; };

  my $vrow = $vsth->fetchrow_hashref;
  if ( $vrow ) {
    $hashref->{'vacation_active'}  = $vrow->{'active'};
    $hashref->{'vacation_subject'} = $vrow->{'subject'};
    $hashref->{'vacation_body'}    = $vrow->{'body'};
#what about these?
#| cache   | text         | NO   |     | NULL                |       |
#| domain  | varchar(255) | NO   |     | NULL                |       |
#and disabling "Sender e-mail address for auto-reply message:", no place for it
  }

  ###
  #spam settings
  ###

  my $ssth = $dbh->prepare('SELECT * FROM users WHERE address = ?')
    or do { $hashref->{'error'} = "can't prepare: ". $dbh->errstr; return; };
  $ssth->execute( $svc_acct->email )
    or do { $hashref->{'error'} = "can't execute: ". $ssth->errstr; return; };

  my $srow = $ssth->fetchrow_hashref;
  if ( $srow ) {
    $hashref->{'spam_tag_level'}     = $srow->{'spam_tag_level'};
    $hashref->{'spam_tag2_level'}    = $srow->{'spam_tag2_level'};
    $hashref->{'spam_kill_level'}    = $srow->{'spam_kill_level'};
    $hashref->{'bypass_spam_checks'} = $srow->{'bypass_spam_checks'};
    $hashref->{'spam_tag2_level'}    = $srow->{'spam_tag2_level'};
  }

  ###
  # spam allow/deny list
  ###

  #my $lsth = $dbh->prepare('SELECT * FROM 

  #htmlref not implemented/used for this status export

}

1;
