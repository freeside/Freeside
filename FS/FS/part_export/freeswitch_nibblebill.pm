package FS::part_export::freeswitch_nibblebill;
use base qw( FS::part_export );

use vars qw( %info ); # $DEBUG );
use Tie::IxHash;
use DBI;
#use FS::Record qw( qsearch ); #qsearchs );
#use FS::svc_phone;
#use FS::Schema qw( dbdef );

#$DEBUG = 1;

tie my %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },                                  
  'username' => { label=>'Database username' },                                 
  'password' => { label=>'Database password' },   
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision prepaid credit to a FreeSWITCH mod_nibblebill database',
  'options' => \%options,
  'notes'   => <<'END',
Provision prepaid credit to a FreeSWITCH mod_nibblebill database.  Use with the <b>Prepaid credit in FreeSWITCH mod_nibblebill</b> price plan.
<br><br>
 See the                                                     
<a href="http://search.cpan.org/dist/DBI/DBI.pm#connect">DBI documentation</a>  
and the                                                                         
<a href="http://search.cpan.org/search?mode=module&query=DBD%3A%3A">documentation for your DBD</a>
for the exact syntax of a DBI data source.
END
);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_phone ) = ( shift, shift );

  #add phonenum to db (unless it is there already)

  # w/the setup amount makes the most sense in this usage (rather than the
  #  (balance/pkg-balance), since you would order the package, then provision
  #   the phone number.
  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $amount = $cust_pkg ? $cust_pkg->part_pkg->option('setup_fee')
                         : '';

  my $queue = new FS::queue {
    svcnum => $svcnum,
    job    => 'FS::part_export::freeswitch_nibblebill::nibblebill_insert',
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    $svc_phone->phonenum,
    $amount,
  );

}

sub nibblebill_insert {
  my($datasrc, $username, $password, $phonenum, $amount) = @_;
  my $dbh = DBI->connect($datasrc, $username, $password) or die $DBI::errstr; 

  #check for existing account
  $dbh->{FetchHashKeyName} = 'NAME_lc';
  my $esth = $dbh->prepare('SELECT id, name, cash FROM accounts WHERE id = ?')
    or die $dbh->errstr;
  $esth->execute($phonenum) or die $esth->errstr;
  my $row = $esth->fetchrow_hashref;

  #die "$phonenum already exists in nibblebill db" if $row && $row->{'id'};
  if ( $row && $row->{'id'} ) {

    nibblebill_adjust_cash($datasrc, $username, $password, $phonenum, $amount);

  } else {

    my $sth = $dbh->prepare(
        'INSERT INTO accounts (id, name, cash) VALUES (?, ?, ?)'
      ) or die $dbh->errsrr;
    $sth->execute($phonenum, $phonenum, $amount) or die $sth->errstr;
 
  }
}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  #XXX change phonenum in db?

  '';
}

sub _export_delete {
  my( $self, $svc_phone) = @_;

  #XXX delete the phonenum in db, suck back any unused credit and make a credit?

  ''
}

sub _adjust {
  my( $self, $svc_phone, $amount ) = @_;

  my $queue = new FS::queue {
    svcnum => $svcnum,
    job    => 'FS::part_export::freeswitch_nibblebill::nibblebill_adjust_cash',
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    $svc_phone->phonenum,
    $amount,
  ) or $queue;
}

sub nibblebill_adjust_cash {
  my($datasrc, $username, $password, $phonenum, $amount) = @_;
  my $dbh = DBI->connect($datasrc, $username, $password) or die $DBI::errstr; 

  my $sth = $dbh->prepare('UPDATE accounts SET cash = cash + ? WHERE id = ?')
    or die $dbh->errsrr;
  $sth->execute($amount, $phonenum) or die $sth->errstr;
}

sub export_getstatus {                                                          
  my( $self, $svc_phone, $htmlref, $hashref ) = @_;             

  my $dbh = DBI->connect( map $self->option($_), qw( datasrc username password ) )
    or return $DBI::errstr; 

  my $sth = $dbh->prepare('SELECT cash FROM accounts WHERE id = ?')
    or return $dbh->errstr;
  $sth->execute($svc_phone->phonenum) or return $sth->errstr;
  my $row = $sth->fetchrow_hashref or return '';

  $hashref->{'Balance'} = $row->{'cash'};

  '';

}

1;
